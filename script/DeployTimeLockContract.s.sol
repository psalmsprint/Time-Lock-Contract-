// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {TimeLockContract} from "../src/TimeLockContract.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployTimeLockContract is Script {
    function run() external returns (TimeLockContract, HelperConfig) {
        HelperConfig helper = new HelperConfig();
        (address governor, uint256 minimumDelay, uint256 gracePeriod) = helper.activeNetworkConfig();

        vm.startBroadcast();
        TimeLockContract timeLockContract = new TimeLockContract(governor, minimumDelay, gracePeriod);
        vm.stopBroadcast();

        return (timeLockContract, helper);
    }
}
