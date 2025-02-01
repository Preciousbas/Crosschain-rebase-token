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
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    // Mint Tests
    function testMintRebaseToken() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        uint256 balance = rebaseToken.balanceOf(user);
        assertEq(balance, 100 ether);
        vm.stopPrank();
    }

    function testMintRebaseTokenOnlyByVault() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 100 ether, 5e10);
    }

    // Burn Tests
    function testBurnRebaseToken() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        rebaseToken.burn(user, 50 ether);
        uint256 balance = rebaseToken.balanceOf(user);
        assertEq(balance, 50 ether);
    }

    function testBurnRebaseTokenOnlyByVault() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.burn(user, 50 ether);
    }

    function testBurnMoreThanBalanceReverts() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 10 ether, rebaseToken.getInterestRate());
        vm.expectRevert();
        rebaseToken.burn(user, 20 ether);
        vm.stopPrank();
    }

    // Transfer Tests
    function testTransferRebaseTokens() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        vm.stopPrank();

        vm.startPrank(user);
        rebaseToken.transfer(recipient, 50 ether);
        uint256 recipientBalance = rebaseToken.balanceOf(recipient);
        uint256 userBalance = rebaseToken.balanceOf(user);
        assertEq(recipientBalance, 50 ether);
        assertEq(userBalance, 50 ether);
        vm.stopPrank();
    }

    function testTransferRebaseTokensToNewUserSetsInterestRate() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        vm.stopPrank();

        vm.startPrank(user);
        rebaseToken.transfer(recipient, 50 ether);
        uint256 recipientRate = rebaseToken.getUserInterestRate(recipient);
        uint256 senderRate = rebaseToken.getUserInterestRate(user);
        assertEq(recipientRate, senderRate);
        vm.stopPrank();
    }

    function testTransferMoreThanBalanceReverts() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.transfer(recipient, 200 ether);
    }

    // Test interest rate
    function testInterestRateCanOnlyDecrease() public {
        vm.startPrank(owner);
        rebaseToken.setInterestRate(5e10);
        assertEq(rebaseToken.getInterestRate(), 5e10);
        vm.expectRevert(
            abi.encodeWithSelector(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, 5e10, 7e10)
        );
        rebaseToken.setInterestRate(7e10); // This should revert as interest rate can only decrease
    }

    function testOnlyOwnerCanSetInterestRate() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(3e10);
        vm.stopPrank();
    }

    function testDifferentGlobalInterestRatesAssignedToDifferentUsers() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 40 ether, rebaseToken.getInterestRate());
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(userInterestRate, rebaseToken.getInterestRate());
        vm.stopPrank();

        // Owner changes the interest rate
        vm.startPrank(owner);
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();

        // New user called 'recipient' mints after the new interest rate has been set
        vm.startPrank(address(vault));
        rebaseToken.mint(recipient, 40 ether, rebaseToken.getInterestRate());
        uint256 recipientInterestRate = rebaseToken.getUserInterestRate(recipient);
        assertEq(recipientInterestRate, rebaseToken.getInterestRate());
        vm.stopPrank();

        assert(userInterestRate != recipientInterestRate);
    }

    function testOldUserInterestRateChangesAfterMintingDuringGlobalNewInterestRate() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 40 ether, rebaseToken.getInterestRate());
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(userInterestRate, rebaseToken.getInterestRate());
        vm.stopPrank();

        // Owner changes the interest rate
        vm.startPrank(owner);
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();

        // Same user mints after the new interest rate has been set
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 40 ether, rebaseToken.getInterestRate());
        uint256 userNewInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(userNewInterestRate, rebaseToken.getInterestRate());
        vm.stopPrank();

        assert(userInterestRate != userNewInterestRate);
    }

    // Test accrued interest
    function testAccruedInterestUpdatesBalance() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        vm.stopPrank();

        // Simulate time passing (e.g., 1 year)
        vm.warp(block.timestamp + 365 days);

        uint256 accruedBalance = rebaseToken.balanceOf(user);
        uint256 principleBalance = rebaseToken.getPrincipleBalanceOf(user);

        assertGt(accruedBalance, principleBalance); // Accrued balance should be greater
    }

    function testReceiverInterestRateAfterTransferSameAsSenders() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        vm.stopPrank();

        vm.startPrank(user);
        rebaseToken.transfer(recipient, 50 ether);
        uint256 recipientInterestRate = rebaseToken.getUserInterestRate(recipient);
        uint256 sendertInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(recipientInterestRate, sendertInterestRate);
    }

    // Test mintAccruedInterest when balance increases
    function testMintAccruedInterestUpdatesBalance() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(user, 100 ether, rebaseToken.getInterestRate());
        vm.warp(600 seconds);
        rebaseToken.mint(user, 2 ether, rebaseToken.getInterestRate());
        vm.stopPrank();

        vm.startPrank(user);
        rebaseToken.transfer(recipient, 50 ether);
        vm.stopPrank();

        uint256 userBalance = rebaseToken.balanceOf(user);
        assertGt(userBalance, 52 ether); // User should also have accrued interest
    }

    // Test assigning roles
    function testAssignMintAndBurnRoleRevertsForUnauthorizedUser() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.mint(recipient, 100 ether, 5e10); // User shouldn't mint
        vm.stopPrank();
    }

    // function testDepositLinear() public {
    //     vm.startPrank(user);
    //     address(vault).deposit
    // }
}
