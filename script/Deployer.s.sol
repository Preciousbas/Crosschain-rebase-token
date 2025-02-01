// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {RebaseTokenPool} from "src/RebaseTokenPool.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        vm.startBroadcast();
        token = new RebaseToken();
        pool = new RebaseTokenPool(
            IERC20(address(token)), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );
        token.assignMintAndBurnRole(address(pool));
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.registryModuleOwnerCustomAddress).acceptAdminRole(address(token));
        TokenAdminRegistry(networkDetails.registryModuleOwnerCustomAddress).setPool(address(token), address(pool));
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run() public returns (Vault vault) {
        IRebaseToken i_rebaseToken;

        vm.startBroadcast();
        vault = new Vault(i_rebaseToken);
        IRebaseToken(address(i_rebaseToken)).assignMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
