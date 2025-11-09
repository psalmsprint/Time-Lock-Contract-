// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/*
* @author 0xNicos
* @dev this contract does receive any token.
* @notice this is use for testing an eth transfer failure.
*/

contract BadReceiver {
    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}
