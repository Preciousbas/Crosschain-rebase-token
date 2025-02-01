// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IRebaseToken} from "src/interfaces/IRebaseToken.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    RebaseToken rebaseToken;
    Vault vault;
    Handler handler;
    IRebaseToken i_rebaseToken;

    uint256 initialVaultBalance = 1000 ether;
    uint256 amountToMint = 20 ether;
    address Bob = makeAddr("Bob");
    address Dylan = makeAddr("Dylan");

    function setUp() public {
        // Deploy the contracts and set up roles
        vm.startPrank(msg.sender);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.assignMintAndBurnRole(address(vault));
        vm.deal(address(vault), initialVaultBalance); // Seed the vault with Ether
        vm.stopPrank();

        handler = new Handler(vault, rebaseToken);

        targetContract(address(handler));
    }

    function invariant_VaultBalanceEqualsUserDeposits() public {
        uint256 handlerVaultBalance = handler.getVaultBalance();

        uint256 user1Deposit = handler.userDeposits(Bob);
        uint256 user2Deposit = handler.userDeposits(Dylan);

        uint256 totalDeposits = user1Deposit + user2Deposit + handlerVaultBalance;

        assertEq(handlerVaultBalance, totalDeposits, "Vault balance does not match user deposits");
    }

    function invariant_BalanceIncludesInterest() public {
        vm.startPrank(address(vault));
        rebaseToken.mint(Bob, amountToMint, rebaseToken.getInterestRate());
        vm.stopPrank();
        vm.warp(600 seconds);
        uint256 user1Balance = rebaseToken.balanceOf(Bob);
        uint256 bobPrincipalBalance = rebaseToken.getPrincipleBalanceOf(Bob);

        // Verify user balance includes accrued interest
        uint256 expectedBalance = bobPrincipalBalance * (1e18 + (rebaseToken.getInterestRate() * 600 seconds)) / 1e18;

        assertApproxEqAbs(user1Balance, expectedBalance, 1e15, "Bob's balance does not include accrued interest");
    }

    function invariant_NoUnauthorizedMintBurn() public {
        // Unauthorized minting or burning should revert
        vm.startPrank(Bob);
        vm.expectRevert();
        rebaseToken.mint(Bob, 1 ether, 5e10);
        vm.stopPrank();

        vm.startPrank(Dylan);
        vm.expectRevert();
        rebaseToken.burn(Dylan, 1 ether);
        vm.stopPrank();
    }

    function invariant_UsersCannotRedeemMoreThanDeposited() public {
        vm.startPrank(Bob);
        vault.deposit{value: 5 ether}();

        vm.expectRevert();
        vault.redeemRewards(10 ether);
        vm.stopPrank();
    }
}
