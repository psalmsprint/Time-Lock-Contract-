// SPX-License-Identifier: MIT

pragma solidity ^0.8.30;

error ReentranceDetected();

abstract contract ReentrancyGuard {
    uint256 private constant ENTERED = 2;
    uint256 private constant NON_ENTERED = 1;

    uint256 private s_status = NON_ENTERED;

    modifier nonReentrance() {
        if (s_status == ENTERED) {
            revert ReentranceDetected();
        }

        s_status = ENTERED;
        _;

        s_status = NON_ENTERED;
    }
}
