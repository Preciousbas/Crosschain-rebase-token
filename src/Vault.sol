// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.27;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    ////////////////////////////////////
    //           ERRORS               //
    ////////////////////////////////////
    error Vault__RedeemFailed();
    error Vault__MustBeMoreThanZero();

    ////////////////////////////////////
    //       STATE VARIABLES          //
    ////////////////////////////////////
    IRebaseToken private immutable i_rebaseToken;

    ////////////////////////////////////
    //           EVENTS               //
    ////////////////////////////////////
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    ////////////////////////////////////
    //           FUNCTIONS            //
    ////////////////////////////////////
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    /**
     * @notice This function is for users who want deposit ETH into the vault after which, they'll get some rebase tokens in return
     */
    function deposit() external payable {
        if (msg.value == 0) {
            revert Vault__MustBeMoreThanZero();
        }
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Users can redeem their rebase tokens for ETH
     * @notice The rebase tokens are burnt after which ETH corresponding to their rewards are sent to them
     * @param _amount This is the amount of rebase tokens the user would love to redeem
     */
    function redeemRewards(uint256 _amount) external {
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");

        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice This function returns the address of the rebase token
     * @return The address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }

    receive() external payable {}
}
