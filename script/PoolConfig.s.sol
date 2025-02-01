// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract PoolConfig is Script {
    function run(
        TokenPool localPool,
        TokenPool remotePool,
        IRebaseToken remoteToken,
        Register.NetworkDetails memory remoteNetworkDetails,
        bool outBoundRateLimiterIsEnabled,
        uint128 outBoundRateLimiterCapacity,
        uint128 outBoundRateLimiterRate,
        bool inBoundRateLimiterIsEnabled,
        uint128 inBoundRateLimiterCapacity,
        uint128 inBoundRateLimiterRate
    ) public {
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);

        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(address(remotePool)),
            remoteTokenAddress: abi.encode(address(remoteToken)),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outBoundRateLimiterIsEnabled,
                capacity: outBoundRateLimiterCapacity,
                rate: outBoundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inBoundRateLimiterIsEnabled,
                capacity: inBoundRateLimiterCapacity,
                rate: inBoundRateLimiterRate
            })
        });

        localPool.applyChainUpdates(chains);
        vm.stopBroadcast();
    }
}
