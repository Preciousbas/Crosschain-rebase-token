// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vault} from "src/Vault.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract Handler is Test {
    Vault private vault;
    RebaseToken private rebaseToken;

    // Track user deposits
    mapping(address => uint256) public userDeposits;

    address[] public usersThatHaveDeposited;
    uint256 constant MAX_DEPOSIT_AMOUNT = type(uint96).max;

    address user = makeAddr("user");
    address Bob = makeAddr("Bob");
    address Dylan = makeAddr("Dylan");

    constructor(Vault _vault, RebaseToken _rebaseToken) {
        vault = _vault;
        rebaseToken = _rebaseToken;

        // // Assign addresses for fuzzing
        // owner = address(1);
        // user1 = address(2);
        // user2 = address(3);
        // vm.label(owner, "Owner");
        // vm.label(user1, "User1");
        // vm.label(user2, "User2");

        // // Seed users with Ether
        vm.deal(Bob, type(uint96).max);
        vm.deal(Dylan, type(uint96).max);
    }

    /// Simulate a deposit
    function deposit(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEPOSIT_AMOUNT);

        if (address(msg.sender).balance < amount) {
            vm.deal(msg.sender, amount + 1 ether);
        }
        vm.prank(msg.sender);
        vault.deposit{value: amount}();
        userDeposits[user] += amount;
    }

    /// Simulate redeeming rewards
    function redeem(uint256 amount) public {
        uint256 maxBalanceOfUser = rebaseToken.balanceOf(msg.sender);
        amount = bound(amount, 0, maxBalanceOfUser);
        if (amount == 0) {
            return;
        }

        vm.prank(msg.sender);
        vault.redeemRewards(amount);
        userDeposits[user] -= amount;
    }

    /// Simulate transferring rebase tokens
    function transfer(address to, uint256 amount) public {
        uint256 maxBalanceOfUser = rebaseToken.balanceOf(msg.sender);
        if (maxBalanceOfUser == 0) {
            return; // Skip if sender has no tokens
        }
        amount = bound(amount, 1, maxBalanceOfUser);
        vm.prank(msg.sender);
        rebaseToken.transfer(to, amount);
    }

    /// Helper to get the total balance in the vault
    function getVaultBalance() public view returns (uint256) {
        return address(vault).balance;
    }

    function mint(uint256 amount, uint256 addressSeed, uint256 userInterestRate) public {
        if (usersThatHaveDeposited.length == 0) {
            return;
        }
        address sender = (usersThatHaveDeposited[addressSeed % usersThatHaveDeposited.length]);

        amount = bound(amount, 1, MAX_DEPOSIT_AMOUNT);
        vm.startPrank(msg.sender);
        rebaseToken.mint(sender, amount, userInterestRate);
        vm.stopPrank();
    }
}
