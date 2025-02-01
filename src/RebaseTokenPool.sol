// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {console} from "forge-std/console.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowlist, address _rmnProxy, address _router)
        TokenPool(_token, _allowlist, _rmnProxy, _router)
    {}

    /**
     * @notice This function would be called when users are sending tokens from the chain this pool is deployed to (source) to another chain (destination)
     * @param lockOrBurnIn The input data for the lock or burn operation.
     *        - originalSender: The address of the sender.
     *        - amount: The amount of tokens to lock or burn which is equal to the amount of tokens sent.
     *        - chainSelector: The identifier of the target blockchain for the cross-chain transfer.
     * @return lockOrBurnOut A struct containing data for the destination chain.
     *         - destTokenAddress: The token address on the destination chain.
     *         - destPoolData: Encoded data containing the sender's interest rate for the destination chain.
     */
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        bool isSupported = isSupportedChain(lockOrBurnIn.remoteChainSelector);
        console.log("Chain supported:", isSupported);
        _validateLockOrBurn(lockOrBurnIn);
        uint256 userInterestrate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestrate)
        });
        console.log("Inside lockOrBurn...");
        console.log("Received remoteChainSelector:", lockOrBurnIn.remoteChainSelector);
    }

    /**
     * @notice This function will be called when users are sending tokens to this pool
     * @param releaseOrMintIn The input data for the release or mint operation.
     *        - receiver: The address that will receive the tokens.
     *        - amount: The amount of tokens to release or mint.
     *        - sourcePoolData: Encoded data containing the user's interest rate for rebase calculations.
     * @return A struct containing details about the destination amount.
     *         - destinationAmount: The amount of tokens released or minted to the receiver.
     */
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
