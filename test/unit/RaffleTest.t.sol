// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {LinkToken} from "../mocks/LinkToken.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    address vrfCoordinatorV2_5;
    LinkToken link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);


    function setUp() external{
        DeployRaffle deployer = new DeployRaffle();

        (raffle, helperConfig) = deployer.run();

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        // automationUpdateInterval = config.automationUpdateInterval;
        // raffleEntranceFee = config.raffleEntranceFee;
        // vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        // link = LinkToken(config.link);

    
    }


    function testRaffleInitializedInOpenState() public view {
        // assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(uint256(raffle.getRaffleState()) == 0);
    }


    /*//////////////////////////////////////////////////////////////
                            FOUNDRY-LOTTERY
    //////////////////////////////////////////////////////////////*/

    function testRaffleWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        // Act    // Assert
        vm.expectRevert(Raffle.Raffle__SendMOreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayers(0);
        assertEq(playerRecorded, PLAYER);
    }


    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRAffleIsCalculating() public{
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Revert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act 
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert 
        assert(!upkeepNeeded);
    }

    // Challenge
    // testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed
    // testCheckUpkeepReturnsTrueWhenParametersAreGood


    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyBeCalledIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        // Act  // Assert
        raffle.performUpkeep("");

    }

    function testPerformUpkeepREvertsIfCheckUpkeepIsFalse() public{
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee; 
        numPlayers = numPlayers + 1;

        // act / assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, raffleState));

        raffle.performUpkeep("");
    }

}