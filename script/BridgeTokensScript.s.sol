// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";

import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BrigdeTokensScript is Script {
    function run(
        address tokenToSendAddress,
        uint256 amountToSend,
        address receiverAddress,
        address linkAddress,
        uint64 destinationChainSelector,
        address ccipRouterAddress
    ) public {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenToSendAddress, amount: amountToSend});
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkAddress,
            extraArgs: ""
        });
        uint256 fee = IRouterClient(ccipRouterAddress).getFee(destinationChainSelector, message);
        IERC20(linkAddress).approve(ccipRouterAddress, fee);
        IERC20(tokenToSendAddress).approve(ccipRouterAddress, amountToSend);
        IRouterClient(ccipRouterAddress).ccipSend(destinationChainSelector, message);
    }
}
