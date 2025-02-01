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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Precious Bassey
 * @notice This is cross-chain rebase token ERC-20 contract that incentivises users to deposit into a vault
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user would have their own interest rate that is the same as the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    ////////////////////////////////////
    //           ERRORS               //
    ////////////////////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    ////////////////////////////////////
    //       STATE VARIABLES          //
    ////////////////////////////////////
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;

    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    ////////////////////////////////////
    //           EVENTS               //
    ////////////////////////////////////
    event InterestRateSet(uint256 interestRate);

    ////////////////////////////////////
    //           FUNCTIONS            //
    ////////////////////////////////////
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    //////////////////////////////////////////////
    //       PUBLIC & EXTERNAL FUNCTIONS       //
    /////////////////////////////////////////////

    /**
     * @notice This function assigns users a role to perform other specific tasks (mint and burn) in the protocol
     * @notice Only the owner (deployer) is allowed to assign roles.
     * @param _user The user whose being assigned a role
     * @dev A known security issue would be that the owner can assign a role to anyone he wishes including himself.
     */
    function assignMintAndBurnRole(address _user) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _user);
    }

    /**
     * @notice This function transfers tokens from one user to another
     * @param _recipient The user whose receiving the tokens
     * @param _amount The amount of tokens to be transferred
     * @return True if transfer is successful
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice This function transfers tokens from one user to another
     * @param _sender The user sending or transferring the tokens
     * @param _recipient The user whose receiving the tokens
     * @param _amount The amount of tokens to be transferred
     * @return True if transfer is successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice This function sets a new interest rate
     * @param _newInterestRate is the new interest rate that is to be set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice This function mints some tokens to the user when they deposit into the vault
     * @param _to the user who receives the minted rebase tokens
     * @param _amount the amount of tokens to be minted
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice This function burns some tokens from the user when they withdraw from the vault
     * @param _from the user who withdraws and whose tokens are burnt
     * @param _amount the amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice This function calculates the balance of rebase tokens of the user which includes the interest accrued since the last updated timestamp
     * @notice (principle balance) * interest accrued
     * @param user The user whose balance is being calculated
     * @return The balance of the user including the interest accrued since the last updated timestamp
     */
    function balanceOf(address user) public view override returns (uint256) {
        //get the current principle balance of the user (the number of tokens the user has minted already)
        // multiply the principle balance by the interest rate

        return (super.balanceOf(user) * _calculateUserAccumulatedInterestRateSinceLastUpdated(user)) / PRECISION_FACTOR;
    }

    /////////////////////////////////////////
    //    PRIVATE & INTERNAL FUNCTIONS    //
    ////////////////////////////////////////
    /**
     * @notice This function mints the accrued interest to the user since the last time they interacted with the protocol (burn, transfer, deposit)
     * @param _user The user whose accumulated interest is being minted to.
     */
    function _mintAccruedInterest(address _user) internal {
        // [1] find the current balance of rebase tokens minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // [2] calculate the current balance including the interest accrued
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens to be minted to the user. [2] - [1]
        uint256 balanceIncreasedBy = currentBalance - previousPrincipleBalance;
        // set the last updated timestamp of the user
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // mint the tokens to the user
        _mint(_user, balanceIncreasedBy);
    }

    /**
     * @notice Calculates the interest accumulated since the last update
     * @param _user The user whose interest accrued is to be calculated
     * @return linearInterest The interest accumulated since the last updated timestamp
     */
    function _calculateUserAccumulatedInterestRateSinceLastUpdated(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_interestRate * timeElapsed);
    }

    /**
     * @notice Gets the user's interest rate
     * @param _user the user whose interest rate is to be got
     * @return the user's interest rate.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice Gets the interest rate that is currently set for the contract. Any new depositors will be assigned this interest rate
     * @return the interest rate of the contract.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice This function gets the principle balance of a user. This is the current balance of tokens minted to the user, not including any interest that has accrued since the last time the user interacted with the protocol
     * @param _user The user whose priciple balance is to be gotten
     * @return The principle balance of the user
     */
    function getPrincipleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
