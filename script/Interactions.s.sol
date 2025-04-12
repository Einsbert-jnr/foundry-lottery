// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";  

contract CreateSubscription is Script {

    function createSubscriptionConfig() public returns (uint256, address){
        HelperConfig helperConfig = new HelperConfig();

        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        // create subscription
        (uint256 subId, ) = createSubscription(vrfCoordinator);

        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address){
       console.log("Creating subscription...", block.chainid);
       vm.startBroadcast();
       uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
       vm.stopBroadcast();
       console.log("Created subscription with ID: ", subId);
       console.log("Please update the subscription ID in your HelperConfig.s.sol");

       return (subId, vrfCoordinator);
    }

    function run() public {}
}