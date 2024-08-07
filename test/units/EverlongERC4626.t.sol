// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";

/// @dev Tests EverlongERC4626 functionality.
contract TestEverlongERC4626 is EverlongTest {
    // ╭─────────────────────────────────────────────────────────╮
    // │ Deposit/Mint                                            │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Validates that `deposit()` rebalances positions.
    function test_deposit_causes_rebalance() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint bob some assets and approve the Everlong contract.
        mintApproveHyperdriveBase(bob, 1e18);

        // Deposit assets into Everlong as Bob.
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit IEverlongEvents.Rebalanced();
        everlong.deposit(1e18, bob);
        vm.stopPrank();
    }

    /// @dev Validates that `_afterDeposit` increases total assets.
    function test_afterDeposit_virtual_asset_increase() external {
        // Call `_afterDeposit` with some assets.
        everlong.exposed_afterDeposit(5, 1);
        // Ensure `totalAssets()` is increased by the correct amount.
        assertEq(everlong.totalAssets(), 5);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Withdraw/Redeem                                         │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Validates that `redeem()` will close all positions with a
    //       mature position sufficient to cover withdrawal amount.
    function test_redeem_close_positions_mature() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint Bob and Celine some assets and approve the Everlong contract.
        mintApproveHyperdriveBase(bob, 10e18);
        mintApproveHyperdriveBase(celine, 2e18);

        // Deposit assets into Everlong as Bob.
        vm.startPrank(bob);
        everlong.deposit(1e18, bob);
        vm.stopPrank();

        // Advance time by a checkpoint so that future deposits result in
        // new positions.
        advanceTime(hyperdrive.getPoolConfig().checkpointDuration, 0);

        // Confirm that Everlong currently does not have a matured position.
        assertFalse(everlong.hasMaturedPositions());

        // Deposit assets into Everlong as Celine to create another position.
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

        // Confirm that Everlong now has one immature position.
        assertEq(everlong.getPositionCount(), 1);
        assertGt(everlong.getPosition(0).maturityTime, block.timestamp);
    }

    /// @dev Validates that `redeem()` will close all positions when closing
    ///      an immature position is required to service the withdrawal.
    function test_redeem_close_all_positions_immature() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint Bob and Celine some assets and approve the Everlong contract.
        mintApproveHyperdriveBase(bob, 10e18);

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
