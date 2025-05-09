// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions


// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";


/**
 * @title Raffle Contract
 * @author Einsbert 
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */


contract Raffle is VRFConsumerBaseV2Plus {

    /* Errors */
    error Raffle__SendMOreToEnterRaffle(); // best practice is to precede with contract name
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 length, uint256 s_raffleState);

    /* Type declarations */
    enum RaffleState{
        OPEN,               // can be converted to int // 0
        CALCULATING         //1
    }

    uint16 private constant REQUEST_CONFIRMATONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev The duration of the raffle in seconds
    uint256 private immutable i_interval; 
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);


    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator,
                bytes32 gasLane, uint256 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus (vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_vrfCoordinator.requestRandomWords;
        s_raffleState = RaffleState.OPEN; // same as RaffleState[]
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        // if (msg.value < i_entranceFee){
        //     revert raffleNotEnoughETHSent();
        // }

        // another update that allows require to take errors

        if (msg.value < i_entranceFee){
            revert Raffle__SendMOreToEnterRaffle();
            }

        if (s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        // 1. makes migration easier
        // 2. makes front end "indexing" easier

        emit RaffleEntered(msg.sender);
    }


    /**
     * @dev This is the function that the chainlink nodes will call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in order for the winnerPicked to be true:
     * 1. The time interval has passed between raffle run
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param -ignored 
     * @return upkeepNeeded - true if its time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(bytes memory /*checkData*/) public view returns (bool upkeepNeeded, bytes memory /* performData */){
        bool timeHasPassed = (block.timestamp  - s_lastTimeStamp >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }


    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        // Check to see if enough time has passed
        (bool upKeepNeeded,) = checkUpkeep("");
        if (!upKeepNeeded){
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        // Get our random number from chainlink
        // 1. Request RNG
        // 2. Get RNG

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

            uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
            emit RequestedRaffleWinner(requestId);

    }
    
   // CEI: Check Effect Interactions Pattern
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual override{
        // Checks (basically require statements)


       // s_player = 10         // rng = 12     //12 % 10 = 2 <- winner is how is at index 2 


       // Effects (internal contract state) where all the state variables are updated
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        // Interactions (External contract interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");

        if (!success){
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(s_recentWinner);
    }


    /**Getter Functions */

    function getEntraceFee() external view returns (uint256){
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_raffleState;
    }

    function getPlayers(uint256 index) external view returns (address){
        return s_players[index];
    } 

    function getLastTimeStamp() external view returns (uint256){
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address){
        return s_recentWinner;
    }

}   
