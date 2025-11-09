// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

error TimeLockContract__InvalidAddress();
error TimeLockContract__MinimumDelayCannotBeZero();
error TimeLockContract__UnAuthorized();
error TimeLockContract__InvalidTimeInput();
error TimeLockContract__InputValidAmount();
error TimeLockContract__TransactionIsExecuted();
error TimeLockContract__NotQueued();
error TimeLockContract__GracePeriodIsActive();
error TimeLockContract__ExecutionFailed();
error TimeLockContract__GracePeriodExpired();
error TimeLockContract__NotYetTime();
error TimeLockContract__GracePeriodIsInvalid();
error TimeLockContract__WaitPeriodIsOver();
error TimeLockContract__WaitPeriodIsActive();

contract TimeLockContract is ReentrancyGuard {
    struct TransactionData {
        address targetedAddress;
        uint256 value;
        bytes data;
        uint256 timeStamp;
        bool executionFlag;
        bool isQueued;
    }

    address private immutable i_governor;
    uint256 private immutable i_minimumDelay;
    uint256 private immutable i_gracePeriod;

    uint256 private s_transactionCount;

    mapping(uint256 transactionId => TransactionData) private s_transactionDetails;

    //____________________________
    // EVENTS
    //____________________________

    event TransactionQueued(
        address indexed targetedAddress, uint256 indexed transactionId, uint256 amount, uint256 timeStamp, bytes data
    );
    event TransactionExecuted(address indexed targetedAddress, uint256 txId);
    event TransactionCanceled(uint256 indexed transactionId);
    event WaitCompleted(uint256 transactionId);

    constructor(address governor, uint256 minimumDelay, uint256 gracePeriod) {
        if (governor == address(0)) {
            revert TimeLockContract__InvalidAddress();
        }

        if (minimumDelay < 1 days) {
            revert TimeLockContract__MinimumDelayCannotBeZero();
        }

        if (gracePeriod < 3 days) {
            revert TimeLockContract__GracePeriodIsInvalid();
        }

        i_governor = governor;
        i_minimumDelay = minimumDelay;
        i_gracePeriod = gracePeriod;
    }

    modifier onlyGovernor() {
        if (msg.sender != i_governor) {
            revert TimeLockContract__UnAuthorized();
        }
        _;
    }

    function queueTransaction(
        uint256 txId,
        address targetAddress,
        uint256 amount,
        bytes calldata data,
        uint256 timeStamp
    ) public onlyGovernor {
        if (targetAddress == address(0)) {
            revert TimeLockContract__InvalidAddress();
        }

        if (amount == 0) {
            revert TimeLockContract__InputValidAmount();
        }

        if (timeStamp < block.timestamp + i_minimumDelay) {
            revert TimeLockContract__InvalidTimeInput();
        }

        TransactionData memory transactionData = TransactionData({
            targetedAddress: targetAddress,
            value: amount,
            data: data,
            timeStamp: timeStamp,
            executionFlag: false,
            isQueued: true
        });

        s_transactionDetails[txId] = transactionData;
        s_transactionCount++;

        emit TransactionQueued(targetAddress, txId, amount, timeStamp, data);
    }

    function waitTransaction(uint256 txId) public onlyGovernor {
        TransactionData storage transactionData = s_transactionDetails[txId];

        if (transactionData.executionFlag) {
            revert TimeLockContract__TransactionIsExecuted();
        }

        if (!transactionData.isQueued) {
            revert TimeLockContract__NotQueued();
        }

        if (block.timestamp > transactionData.timeStamp + i_gracePeriod) {
            revert TimeLockContract__GracePeriodExpired();
        }

        if (block.timestamp < transactionData.timeStamp) {
            revert TimeLockContract__WaitPeriodIsActive();
        }

        emit WaitCompleted(txId);
    }

    function executeTransaction(uint256 txId) public onlyGovernor nonReentrance {
        TransactionData storage transactionData = s_transactionDetails[txId];

        if (block.timestamp > transactionData.timeStamp + i_gracePeriod) {
            revert TimeLockContract__GracePeriodExpired();
        }

        if (transactionData.executionFlag) {
            revert TimeLockContract__TransactionIsExecuted();
        }

        if (!transactionData.isQueued) {
            revert TimeLockContract__NotQueued();
        }

        if (transactionData.timeStamp > block.timestamp) {
            revert TimeLockContract__NotYetTime();
        }

        transactionData.executionFlag = true;
        transactionData.isQueued = false;

        (bool success,) =
            payable(transactionData.targetedAddress).call{value: transactionData.value}(transactionData.data);
        if (success) {
            emit TransactionExecuted(transactionData.targetedAddress, txId);
        } else {
            revert TimeLockContract__ExecutionFailed();
        }
    }

    function cancelTransaction(uint256 txId) public onlyGovernor {
        TransactionData storage transactionData = s_transactionDetails[txId];

        if (transactionData.executionFlag) {
            revert TimeLockContract__TransactionIsExecuted();
        }

        if (!transactionData.isQueued) {
            revert TimeLockContract__NotQueued();
        }

        if (block.timestamp > transactionData.timeStamp + i_gracePeriod) {
            revert TimeLockContract__GracePeriodExpired();
        }

        transactionData.isQueued = false;
        transactionData.executionFlag = false;
        s_transactionCount--;

        emit TransactionCanceled(txId);
    }

    //____________________________
    // Getters
    //____________________________

    function getGovernorAddress() external view returns (address) {
        return i_governor;
    }

    function getMinimumDelay() external view returns (uint256) {
        return i_minimumDelay;
    }

    function getGreacePeriod() external view returns (uint256) {
        return i_gracePeriod;
    }

    function getTransactionCount() external view returns (uint256) {
        return s_transactionCount;
    }

    function getExcutionFlag(uint256 txId) external view returns (bool) {
        TransactionData memory transactionData = s_transactionDetails[txId];

        return transactionData.executionFlag;
    }

    function getQueueStatus(uint256 txId) external view returns (bool) {
        TransactionData memory transactionData = s_transactionDetails[txId];

        return transactionData.isQueued;
    }
}
