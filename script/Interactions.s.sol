// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

// Ensure CodeConstants is defined or imported before usage
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";  
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 1e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}


contract CreateSubscription is Script{

    function createSubscriptionConfig() public returns (uint256, address){
        HelperConfig helperConfig = new HelperConfig();

        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        address account = helperConfig.getConfig().account;
        // create subscription
        (uint256 subId, ) = createSubscription(vrfCoordinator, account);

        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256, address){
       console.log("Creating subscription...", block.chainid);
       vm.startBroadcast(account);
       uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
       vm.stopBroadcast();
       console.log("Created subscription with ID: ", subId);
       console.log("Please update the subscription ID in your HelperConfig.s.sol");

       return (subId, vrfCoordinator);
    }



    function run() public returns (uint256, address){
        // (subId, _vrfCoordinator) = createSubscription(vrfCoordinator);
        createSubscriptionConfig();
    }
}

contract FundSubscription is CodeConstants, Script {

    uint256 public constant FUND_AMOUNT = 3 ether;

    function  fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;

        address account = helperConfig.getConfig().account;

        if (subscriptionId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVRFv2) = createSub.run();
            subscriptionId = updatedSubId;
            vrfCoordinator = updatedVRFv2;
            console.log("New SubId Created! ", subscriptionId, "VRF Address: ", vrfCoordinator);
        }

        
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);

    }

   function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
        console.log("Funding subscription...");
        console.log("vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        }
        else{
            console.log(LinkToken(linkToken).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(linkToken).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        } 
    } 

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(address contractToAddr, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract ", contractToAddr);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddr);
        vm.stopBroadcast();
    }

    function run () public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}