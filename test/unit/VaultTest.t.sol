// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.assignMintAndBurnRole(address(vault));
        vm.deal(user, 10 ether);
        vm.deal(owner, 10 ether);
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    // --- Deposit Tests ---
    function testDeposit() public {
        uint256 initialVaultBalance = address(vault).balance;

        vm.startPrank(user);
        vault.deposit{value: 5 ether}();
        vm.stopPrank();

        uint256 finalVaultBalance = address(vault).balance;
        uint256 userBalance = rebaseToken.balanceOf(user);

        assertEq(finalVaultBalance, initialVaultBalance + 5 ether, "Vault balance mismatch after deposit");
        assertEq(userBalance, 5 ether, "User should have received rebase tokens equal to ETH deposited");
    }

    function testDepositEmitsEvent() public {
        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit Vault.Deposit(user, 3 ether);
        vault.deposit{value: 3 ether}();
        vm.stopPrank();
    }

    function testDepositZeroReverts() public {
        vm.startPrank(user);
        vm.expectRevert(Vault.Vault__MustBeMoreThanZero.selector);
        vault.deposit{value: 0}();
        vm.stopPrank();
    }

    // --- Redeem Tests ---
    function testRedeem() public {
        vm.startPrank(user);
        vault.deposit{value: 5 ether}();
        vm.stopPrank();

        uint256 initialUserBalance = user.balance;

        vm.startPrank(user);
        vault.redeemRewards(3 ether);
        vm.stopPrank();

        uint256 finalUserBalance = user.balance;
        uint256 userRebaseTokenBalance = rebaseToken.balanceOf(user);

        assertEq(finalUserBalance, initialUserBalance + 3 ether, "User ETH balance mismatch after redeem");
        assertEq(userRebaseTokenBalance, 2 ether, "User rebase token balance mismatch after redeem");
    }

    function testRedeemFailsIfNotEnoughRebaseTokens() public {
        vm.startPrank(user);
        vault.deposit{value: 5 ether}();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        vault.redeemRewards(6 ether); // Exceeds balance
        vm.stopPrank();
    }

    // function testRedeemFailsIfTransferReverts() public {
    //     vm.startPrank(user);
    //     vault.deposit{value: 5 ether}();
    //     vm.stopPrank();

    //     // Drain Vault balance
    //     vm.startPrank(owner);
    //     (bool success,) = payable(recipient).call{value: address(vault).balance}("");
    //     assertTrue(success);
    //     assertEq(address(vault).balance, 0, "Vault balance should be 0");
    //     vm.stopPrank();

    //     vm.startPrank(user);
    //     // vm.expectRevert(Vault.Vault__RedeemFailed.selector);
    //     vault.redeemRewards(2 ether);
    //     vm.stopPrank();
    // }

    function testRedeemEmitsEvent() public {
        vm.startPrank(user);
        vault.deposit{value: 5 ether}();
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectEmit(true, true, false, true);
        emit Vault.Redeem(user, 3 ether);
        vault.redeemRewards(3 ether);
        vm.stopPrank();
    }

    // --- Rebase Token Address Tests ---
    function testGetRebaseTokenAddress() public {
        address tokenAddress = vault.getRebaseTokenAddress();
        assertEq(tokenAddress, address(rebaseToken), "Rebase token address mismatch");
    }

    // --- Edge Cases ---
    function testRedeemExactBalance() public {
        vm.startPrank(user);
        vault.deposit{value: 5 ether}();
        vm.stopPrank();

        vm.startPrank(user);
        vault.redeemRewards(5 ether);
        vm.stopPrank();

        uint256 userRebaseTokenBalance = rebaseToken.balanceOf(user);
        assertEq(userRebaseTokenBalance, 0, "User should have zero rebase token balance after redeeming all");
    }

    function testReceiveFunctionAllowsEther() public {
        vm.startPrank(user);
        (bool success,) = payable(address(vault)).call{value: 1 ether}("");
        assertTrue(success, "Ether transfer to Vault failed");
        vm.stopPrank();
    }
}
