// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import "../src/TimeLockContract.sol";
import {DeployTimeLockContract} from "../script/DeployTimeLockContract.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {BadReceiver} from "./mocks/BadReceiver.sol";
import "../src/utils/ReentrancyGuard.sol";
import {Attacker} from "./mocks/Attacker.sol";

contract TimeLockContractTest is Test {
    TimeLockContract timeLockContract;
    DeployTimeLockContract deployer;
    HelperConfig helper;
    BadReceiver badReceiver;

    address private governor = makeAddr("governor");
    address private targetedAddress = makeAddr("targetedAddress");

    uint256 private minimumDelay;
    uint256 private gracePeriod;
    uint256 private txId;

    uint256 private constant AMOUNT = 1 ether;

    uint256 private constant STARTING_USER_BALANCE = 100 ether;

    event TransactionQueued(
        address indexed targetedAddress, uint256 indexed transactionId, uint256 amount, uint256 timeStamp, bytes data
    );
    event TransactionExecuted(address indexed targetedAddress, uint256 txId);
    event TransactionCanceled(uint256 indexed transactionId);
    event WaitCompleted(uint256 transactionId);

    function setUp() external {
        deployer = new DeployTimeLockContract();
        (timeLockContract, helper) = deployer.run();

        (governor, minimumDelay, gracePeriod) = helper.activeNetworkConfig();

        badReceiver = new BadReceiver();

        vm.deal(governor, STARTING_USER_BALANCE);
        vm.deal(address(timeLockContract), STARTING_USER_BALANCE);
    }

    modifier queuedTransaction() {
        vm.prank(governor);
        timeLockContract.queueTransaction(txId, targetedAddress, AMOUNT, "", 5 days);
        _;
    }

    //______________________________
    // CONSTRUCTOR
    //______________________________

    function testRevetWhenGovernorAddressIsZero() public {
        vm.prank(msg.sender);
        vm.expectRevert(TimeLockContract__InvalidAddress.selector);
        new TimeLockContract(address(0), 2 days, 7 days);
    }

    function testRevertWhenMinimumDelayIsLessThanADay() public {
        vm.prank(msg.sender);
        vm.expectRevert(TimeLockContract__MinimumDelayCannotBeZero.selector);
        new TimeLockContract(governor, block.timestamp, 3 days);
    }

    function testRevetWhenGracePeriodIsLessThanRequiredDays() public {
        vm.prank(msg.sender);
        vm.expectRevert(TimeLockContract__GracePeriodIsInvalid.selector);
        new TimeLockContract(governor, minimumDelay, 1 days);
    }

    function testConstructorPassAndUpateState() public {
        vm.prank(msg.sender);
        TimeLockContract time = new TimeLockContract(governor, minimumDelay, gracePeriod);

        assertEq(time.getGovernorAddress(), governor);
        assertEq(time.getMinimumDelay(), minimumDelay);
        assertEq(time.getGreacePeriod(), gracePeriod);
    }

    //______________________________
    // QueueTransaction
    //______________________________

    function testQueueTransactionRevertWhwnTargetedAddressIsZero() public {
        vm.prank(governor);
        vm.expectRevert(TimeLockContract__InvalidAddress.selector);
        timeLockContract.queueTransaction(txId, address(0), AMOUNT, "", block.timestamp);
    }

    function testQueueTransactionRevertWhenAmountIsZero() public {
        vm.prank(governor);
        vm.expectRevert(TimeLockContract__InputValidAmount.selector);
        timeLockContract.queueTransaction(txId, targetedAddress, 0, "", 3 days);
    }

    function testQueueTransactionRevertWhenTimeIsLessThanMinimumDelay() public {
        vm.prank(governor);
        vm.expectRevert(TimeLockContract__InvalidTimeInput.selector);
        timeLockContract.queueTransaction(txId, targetedAddress, AMOUNT, "", block.timestamp);
    }

    function test_FuzzQueueTransactionPassedEmitEventAndUpdateState(uint256 transactionId) public {
        vm.assume(transactionId > 1 && transactionId < 30);

        vm.expectEmit(true, true, false, false);
        emit TransactionQueued(targetedAddress, transactionId, AMOUNT, minimumDelay, "");

        vm.prank(governor);
        timeLockContract.queueTransaction(transactionId, targetedAddress, AMOUNT, "", 5 days);

        assertEq(timeLockContract.getTransactionCount(), 1);
    }

    //______________________________
    // WaitTransaction
    //______________________________

    function test_FuzzWaitTransactionRevertWhenTransactionIsNotQueued(uint256 transactionId) public {
        vm.assume(transactionId > 1 && transactionId < 10);

        vm.prank(governor);
        timeLockContract.queueTransaction(transactionId, targetedAddress, AMOUNT, "", 5 days);

        vm.warp(block.timestamp + 5 days);

        vm.prank(governor);
        timeLockContract.executeTransaction(transactionId);

        vm.prank(governor);
        vm.expectRevert(TimeLockContract__TransactionIsExecuted.selector);
        timeLockContract.waitTransaction(transactionId);
    }

    function testWaitTransactionRevertWhenTransactionIsNotQueued() public {
        vm.prank(governor);
        vm.expectRevert(TimeLockContract__NotQueued.selector);
        timeLockContract.waitTransaction(txId);
    }

    function testWaitTransactionRevertWhenGracePeriodIsExpiered() public queuedTransaction {
        vm.warp(block.timestamp + 13 days);

        vm.prank(governor);
        vm.expectRevert(TimeLockContract__GracePeriodExpired.selector);
        timeLockContract.waitTransaction(txId);
    }

    function testRevertWhenWaitPeriodIsActive() public queuedTransaction {
        vm.prank(governor);
        vm.expectRevert(TimeLockContract__WaitPeriodIsActive.selector);
        timeLockContract.waitTransaction(txId);
    }

    function testWaitTransactionPassedAndEmitEvent() public queuedTransaction {
        vm.warp(block.timestamp + 5 days);

        vm.expectEmit(false, false, false, false);
        emit WaitCompleted(txId);

        vm.prank(governor);
        timeLockContract.waitTransaction(txId);
    }

    //______________________________
    // ExecuteTransaction
    //______________________________

    function testExecuteTransactionRevertWhenGracePeriodAsExpiered() public queuedTransaction {
        vm.warp(block.timestamp + 12 days);

        vm.prank(governor);
        vm.expectRevert(TimeLockContract__GracePeriodExpired.selector);
        timeLockContract.executeTransaction(txId);
    }

    function testExecuteTransactionRevertWhenExcutionFlagIsTrue() public queuedTransaction {
        vm.warp(block.timestamp + 5 days);

        vm.prank(governor);
        timeLockContract.executeTransaction(txId);

        vm.warp(block.timestamp + 2 days);

        vm.prank(governor);
        vm.expectRevert(TimeLockContract__TransactionIsExecuted.selector);
        timeLockContract.executeTransaction(txId);
    }

    function testExecuteTransactionRevertWhenTransactionIsNotQueued() public {
        vm.prank(governor);
        vm.expectRevert(TimeLockContract__NotQueued.selector);
        timeLockContract.executeTransaction(txId);
    }

    function testExecuteTransactionRevertWhenItNotTime() public queuedTransaction {
        vm.warp(block.timestamp + 2 days);

        vm.prank(governor);
        vm.expectRevert(TimeLockContract__NotYetTime.selector);
        timeLockContract.executeTransaction(txId);
    }

    function test_FuzzRevertWhenExcuteTransactionFailed(uint256 transactionId) public {
        vm.assume(transactionId > 10 && transactionId < 100);

        vm.prank(governor);
        timeLockContract.queueTransaction(transactionId, address(badReceiver), AMOUNT, "", 5 days);

        vm.warp(block.timestamp + 5 days);

        vm.prank(governor);
        vm.expectRevert(TimeLockContract__ExecutionFailed.selector);
        timeLockContract.executeTransaction(transactionId);
    }

    function test_FuzzExcuteTransactionPassedUpdateStateAndEmitEvent(uint256 transactionId) public {
        vm.assume(transactionId > 10 && transactionId < 100);

        vm.startPrank(governor);
        timeLockContract.queueTransaction(transactionId, targetedAddress, AMOUNT, "", 5 days);

        vm.warp(block.timestamp + 6 days);

        vm.expectEmit(true, false, false, false);
        emit TransactionExecuted(targetedAddress, transactionId);

        timeLockContract.executeTransaction(transactionId);

        vm.stopPrank();

        assert(timeLockContract.getExcutionFlag(transactionId) == true);
        assert(timeLockContract.getQueueStatus(transactionId) == false);
    }

    //______________________________
    // CancelTransaction
    //______________________________

    function testCancelTransactionRevertWhenTransactionIsNotQueued() public {
        vm.prank(governor);
        vm.expectRevert(TimeLockContract__NotQueued.selector);
        timeLockContract.cancelTransaction(txId);
    }

    function testCancelTransactionRevertWhenTransactionExcuted() public queuedTransaction {
        vm.warp(block.timestamp + 6 days);

        vm.startPrank(governor);
        timeLockContract.executeTransaction(txId);

        vm.expectRevert(TimeLockContract__TransactionIsExecuted.selector);
        timeLockContract.cancelTransaction(txId);
        vm.stopPrank();
    }

    function testCancelTransactionRevertWhenGracePeriodEllapse() public queuedTransaction {
        vm.warp(block.timestamp + 15 days);

        vm.prank(governor);
        vm.expectRevert(TimeLockContract__GracePeriodExpired.selector);
        timeLockContract.cancelTransaction(txId);
    }

    function test_FuzzCancelTransactionPassedEmitEventAndUpdateState(uint256 transactionId) public {
        vm.assume(transactionId > 10 && transactionId < 100);

        vm.startPrank(governor);
        timeLockContract.queueTransaction(transactionId, targetedAddress, AMOUNT, "", 5 days);

        vm.expectEmit(true, false, false, false);
        emit TransactionCanceled(transactionId);

        timeLockContract.cancelTransaction(transactionId);

        assert(timeLockContract.getExcutionFlag(transactionId) == false);
        assertEq(timeLockContract.getQueueStatus(transactionId), false);
        assertEq(timeLockContract.getTransactionCount(), 0);
    }

    //______________________________
    // 	ModifierTest
    //______________________________

    function testRevertWhenARanDomUserCalledQueueTransaction() public {
        vm.prank(msg.sender);
        vm.expectRevert(TimeLockContract__UnAuthorized.selector);
        timeLockContract.queueTransaction(txId, targetedAddress, AMOUNT, "", 5 days);
    }

    function testRevertWhenRandomUserCalledWaitTransaction() public {
        vm.prank(targetedAddress);
        vm.expectRevert(TimeLockContract__UnAuthorized.selector);
        timeLockContract.waitTransaction(txId);
    }

    function testRevertWhenUserCalledExecuteTransaction() public {
        vm.prank(msg.sender);
        vm.expectRevert(TimeLockContract__UnAuthorized.selector);
        timeLockContract.executeTransaction(txId);
    }

    function testRevertWhenRandomUserCalledCancelTransaction() public {
        vm.prank(msg.sender);
        vm.expectRevert(TimeLockContract__UnAuthorized.selector);
        timeLockContract.cancelTransaction(txId);
    }

    //______________________________
    // ReentrancyGuard
    //______________________________

    function test_FuzzTimeLockContractReverWhenReentered(uint256 transactionId) public {
        Attacker attacker = new Attacker();

        TimeLockContract attackerLock = new TimeLockContract(address(attacker), 3 days, 4 days);

        attacker.setAttackerAddress(address(attackerLock));

        vm.deal(address(attackerLock), STARTING_USER_BALANCE);

        vm.prank(address(attacker));
        attackerLock.queueTransaction(transactionId, address(attacker), AMOUNT, "", 4 days);

        vm.warp(block.timestamp + 7 days);

        vm.prank(address(attacker));
        vm.expectRevert(TimeLockContract__ExecutionFailed.selector);
        attacker.attack(transactionId);
    }
}
