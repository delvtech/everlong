// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";

/// @dev Tests EverlongERC4626 functionality.
contract TestEverlongERC4626 is EverlongTest {
    /// @dev Validates behavior of the `deposit()` function for a single
    ///        depositor.
    ///  @dev When calling the `deposit()` function...
    ///       1. The `Rebalanced` event should be emitted
    ///       2. The balance of the Everlong contract should be minimal.
    ///       3. The share amount issued to the depositor should be equal to the
    ///           total supply of Everlong shares.
    ///       4. The amount of assets deposited should relate to the share
    ///           count as follows:
    ///           shares_issued = assets_deposited * (10 ^ decimalsOffset)
    function test_deposit_single_depositor() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint bob some assets and approve the Everlong contract.
        uint256 depositAmount = 1e18;
        mintApproveEverlongBaseAsset(bob, depositAmount);

        // 1. Deposit assets into Everlong as Bob and confirm `Rebalanced` event
        //    is emitted.
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit IEverlongEvents.Rebalanced();
        everlong.deposit(depositAmount, bob);
        vm.stopPrank();

        // 2. Confirm that Everlong's balance is less than Hyperdrive's
        //    minimum transaction amount.
        assertLt(
            ERC20Mintable(everlong.asset()).balanceOf(address(everlong)),
            hyperdrive.getPoolConfig().minimumTransactionAmount,
            "Everlong balance should be below min tx amount after single depositor deposit+rebalance"
        );

        // 3. Confirm that Bob's share balance equals the total supply of shares.
        assertEq(
            everlong.balanceOf(bob),
            everlong.totalSupply(),
            "single depositor share balance should equal total supply of shares"
        );

        // 4. Confirm `shares_issued = assets_deposited * (10 ^ decimalsOffset)`
        assertEq(
            everlong.balanceOf(bob),
            depositAmount * (10 ** everlong.decimalsOffset())
        );
    }

    /// @dev Validates that `redeem()` will close the necessary positions with a
    ///       mature position sufficient to cover withdrawal amount.
    function test_redeem_close_positions_mature() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Deposit assets into Everlong as Bob.
        mintApproveEverlongBaseAsset(bob, 10e18);
        vm.startPrank(bob);
        everlong.deposit(1e18, bob);
        vm.stopPrank();

        // Advance time by a checkpoint so that future deposits result in
        // new positions.
        advanceTime(hyperdrive.getPoolConfig().checkpointDuration, 0);

        // Confirm that Everlong currently does not have a matured position.
        assertFalse(everlong.hasMaturedPositions());

        // Deposit assets into Everlong as Celine to create another position.
        mintApproveEverlongBaseAsset(celine, 2e18);
        vm.startPrank(celine);
        everlong.deposit(2e18, celine);
        vm.stopPrank();

        // Confirm that Everlong now has two positions.
        assertEq(everlong.getPositionCount(), 2);

        // Advance time to mature Bob's position but not Celine's.
        advanceTime(everlong.getPosition(0).maturityTime - block.timestamp, 0);

        // Confirm that Everlong now has a matured position.
        assertTrue(everlong.hasMaturedPositions());

        // Redeem all of Bob's shares.
        vm.startPrank(bob);
        everlong.redeem(everlong.balanceOf(bob), bob, bob);
        vm.stopPrank();

        // Confirm that Everlong has two immature positions:
        // 1. Created from Celine's deposit.
        // 2. Created from rebalance on Bob's redemption.
        assertEq(everlong.getPositionCount(), 2);
        assertGt(everlong.getPosition(0).maturityTime, block.timestamp);
    }

    /// @dev Validates that `redeem()` will close all positions when closing
    ///      an immature position is required to service the withdrawal.
    function test_redeem_close_positions_immature() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint Bob and Celine some assets and approve the Everlong contract.
        mintApproveEverlongBaseAsset(bob, 10e18);

        // Deposit assets into Everlong as Bob.
        vm.startPrank(bob);
        everlong.deposit(1e18, bob);
        vm.stopPrank();

        // Advance time by a checkpoint so that future deposits result in
        // new positions.
        advanceTime(hyperdrive.getPoolConfig().checkpointDuration, 0);

        // Confirm that Everlong currently does not have a matured position.
        assertFalse(everlong.hasMaturedPositions());

        // Deposit more assets into Everlong as Bob to create another position.
        vm.startPrank(bob);
        everlong.deposit(2e18, bob);
        vm.stopPrank();

        // Confirm that Everlong now has two positions.
        assertEq(everlong.getPositionCount(), 2);

        // Advance time to mature only the first position.
        advanceTime(everlong.getPosition(0).maturityTime - block.timestamp, 0);

        // Confirm that Everlong now has a matured position.
        assertTrue(everlong.hasMaturedPositions());

        // Redeem all of Bob's shares.
        vm.startPrank(bob);
        everlong.redeem(everlong.balanceOf(bob), bob, bob);
        vm.stopPrank();

        // Confirm that Everlong now has only the position created from
        // rebalancing on Bob's redemption.
        assertEq(everlong.getPositionCount(), 1);
    }

    /// @dev Ensure that the `hyperdrive()` view function is implemented.
    function test_hyperdrive() external view {
        assertEq(
            everlong.hyperdrive(),
            address(hyperdrive),
            "hyperdrive() should return hyperdrive address"
        );
    }

    /// @dev Ensure that the `asset()` view function is implemented.
    function test_asset() external view {
        assertEq(
            everlong.asset(),
            address(hyperdrive.baseToken()),
            "asset() should return hyperdrive base token address"
        );
    }

    /// @dev Ensure that the `name()` view function is implemented.
    function test_name() external view {
        assertNotEq(everlong.name(), "", "name() not return an empty string");
    }

    /// @dev Ensure that the `symbol()` view function is implemented.
    function test_symbol() external view {
        assertNotEq(
            everlong.symbol(),
            "",
            "symbol() not return an empty string"
        );
    }

    /// @dev Validates that `maxDeposit(..)` returns a value that is
    ///      reasonable (less than uint256.max) and actually depositable.
    function test_maxDeposit_is_depositable() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Ensure that `maxDeposit(Bob)` is less than uint256.max.
        uint256 maxDeposit = everlong.maxDeposit(bob);
        assertLt(maxDeposit, type(uint256).max);

        // Attempt to deposit `maxDeposit` as Bob.
        mintApproveEverlongBaseAsset(bob, maxDeposit);
        vm.startPrank(bob);
        everlong.deposit(maxDeposit, bob);
        vm.stopPrank();
    }

    /// @dev Validates that `maxDeposit(..)` decreases when a deposit is made.
    function test_maxDeposit_decreases_after_deposit() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Make the maximum deposit as Bob.
        uint256 maxDeposit = everlong.maxDeposit(bob);
        mintApproveEverlongBaseAsset(bob, maxDeposit);
        vm.startPrank(bob);
        everlong.deposit(maxDeposit, bob);
        vm.stopPrank();

        // Ensure that the new maximum deposit is less than before.
        assertLt(
            everlong.maxDeposit(bob),
            maxDeposit,
            "max deposit should decrease after a deposit is made"
        );
    }

    /// @dev Validates that `_afterDeposit` increases total assets.
    function test_afterDeposit_virtual_asset_increase() external {
        // Call `_afterDeposit` with some assets.
        everlong.exposed_afterDeposit(5, 1);

        // Ensure `totalAssets()` is increased by the correct amount.
        assertEq(everlong.totalAssets(), 5);
    }

    /// @dev Validates that `_beforeWithdraw` decreases total assets.
    function test_beforeWithdraw_virtual_asset_decrease() external {
        // Call `_afterDeposit` to increase total asset count.
        everlong.exposed_afterDeposit(5, 1);

        // Mint Everlong some assets so it can pass the withdrawal
        // balance check.
        ERC20Mintable(everlong.asset()).mint(address(everlong), 5);

        // Call `_beforeWithdraw` to decrease total asset count.
        everlong.exposed_beforeWithdraw(5, 1);

        // Ensure `totalAssets()` is decreased by the correct amount.
        assertEq(everlong.totalAssets(), 0);
    }
}
