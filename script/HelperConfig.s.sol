// SPX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address governor;
        uint256 minimumDelay;
        uint256 gracePeriod;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 84532) {
            activeNetworkConfig = baseSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfi();
        }
    }

    function baseSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory baseSepolia = NetworkConfig({
            governor: 0xC7a2e256FF1b3a09eab71f0fD54c0326982De4e9,
            minimumDelay: 4 days,
            gracePeriod: 7 days
        });

        return baseSepolia;
    }

    function getOrCreateAnvilConfi() public pure returns (NetworkConfig memory) {
        NetworkConfig memory anvilConfig = NetworkConfig({
            governor: 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720,
            minimumDelay: 4 days,
            gracePeriod: 7 days
        });

        return anvilConfig;
    }
}
