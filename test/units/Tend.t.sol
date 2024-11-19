// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";

contract TestTend is EverlongTest {
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;
    using HyperdriveExecutionLibrary for *;

    /// @dev Tests that the gas cost for closing the maximum amount of matured
    ///      positions does not exceed the block gas limit.
    function test_tend_max_matured_positions() external {
        // Calculate the maximum amount of positions possible with the current
        // position and checkpoint durations.
        uint256 maxPositionCount = POSITION_DURATION / CHECKPOINT_DURATION;

        // Loop through and make deposits each checkpoint interval.
        // Keep track of shares for the redeem call later which will force
        // the closure of the matured positions.
        uint256 shares;
        uint256 spent;
        for (uint256 i; i < maxPositionCount; i++) {
            spent += MINIMUM_TRANSACTION_AMOUNT * 200;
            shares += depositVault(
                MINIMUM_TRANSACTION_AMOUNT * 200,
                alice,
                true
            );
            advanceTimeWithCheckpoints(CHECKPOINT_DURATION);
        }

        // Ensure Everlong has the maximum amount of positions possible.
        assertEq(strategy.positionCount(), maxPositionCount);

        // Advance time so that all positions are mature.
        advanceTimeWithCheckpoints(POSITION_DURATION);

        rebalance();
        report();

        // Track the gas cost for the redemption.
        uint256 gasUsed = gasleft();
        redeemVault(shares, alice);
        gasUsed -= gasleft();

        // Ensure the gas cost of the redemption is less than the block gas
        // limit.
        uint256 blockGasLimit = 30_000_000;
        assertLt(gasUsed, blockGasLimit);
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              TendTrigger                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Ensure that `tendTrigger()` returns false when everlong has
    ///      no positions nor balance.
    function test_tendTrigger_false_no_positions_no_balance() external view {
        // Check that Everlong:
        // - has no positions
        // - has no balance
        // - `tendTrigger()` returns false
        assertEq(
            strategy.positionCount(),
            0,
            "everlong should not intialize with positions"
        );
        assertEq(
            IERC20(vault.asset()).balanceOf(address(vault)),
            0,
            "everlong should not initialize with a balance"
        );
        (bool canTend, ) = strategy.tendTrigger();
        assertFalse(
            canTend,
            "cannot rebalance without matured positions or balance"
        );
    }

    /// @dev Ensures that `tendTrigger()` returns true with a balance
    ///          greater than Hyperdrive's minTransactionAmount.
    function test_tendTrigger_with_balance_over_min_tx_amount() external {
        // Mint some tokens to Everlong for opening longs.
        // Ensure Everlong's balance is gte Hyperdrive's minTransactionAmount.
        // Ensure `tendTrigger()` returns true.
        depositStrategy(MINIMUM_TRANSACTION_AMOUNT + 1, alice);
        assertGt(
            IERC20(strategy.asset()).balanceOf(address(strategy)),
            MINIMUM_TRANSACTION_AMOUNT
        );
        (bool canTend, ) = strategy.tendTrigger();
        assertTrue(
            canTend,
            "everlong should be able to rebalance when it has a balance > hyperdrive's minTransactionAmount"
        );
    }

    /// @dev Ensures that `tendTrigger()` returns true with a matured
    ///      position.
    function test_tendTrigger_with_matured_position() external {
        // Mint some tokens to Everlong for opening longs and rebalance.
        mintApproveEverlongBaseAsset(
            address(strategy),
            MINIMUM_TRANSACTION_AMOUNT
        );
        rebalance();

        // Increase block.timestamp until position is mature.
        // Ensure Everlong has a matured position.
        // Ensure `tendTrigger()` returns true.
        advanceTimeWithCheckpoints(strategy.positionAt(0).maturityTime);
        assertTrue(
            strategy.hasMaturedPositions(),
            "everlong should have matured position after advancing time"
        );
        (bool canTend, ) = strategy.tendTrigger();
        assertTrue(
            canTend,
            "everlong should allow rebalance with matured position"
        );
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              TendConfig                               │
    // ╰───────────────────────────────────────────────────────────────────────╯

    // ── minOutput ───────────────────────────────────────────────────────

    /// @dev Tests that `setMinOutput` cannot be called by a non-keeper.
    function test_setMinOutput_failure_not_keeper() external {
        // Start a prank as a non-keeper address (alice).
        vm.startPrank(alice);

        // setMinOutput should revert.
        vm.expectRevert();
        strategy.setMinOutput(1);

        // Stop the prank.
        vm.stopPrank();
    }

    /// @dev Tests that `setMinOutput` succeeds when called by a keeper.
    function test_setMinOutput_suceeds() external {
        // Start a prank as a keeper.
        vm.startPrank(keeper);

        // Call setMinOutput with a non-default value.
        uint256 minOutput = type(uint256).max;
        strategy.setMinOutput(minOutput);

        // Ensure the new value is reflected.
        assertEq(minOutput, strategy.getMinOutput());

        // Stop the prank.
        vm.stopPrank();
    }

    /// @dev Tests that `TendConfig.minOutput` is obeyed when opening longs.
    function test_minOutput_open_long() external {
        // Deposit into the strategy as alice.
        depositStrategy(MINIMUM_TRANSACTION_AMOUNT + 1, alice);

        // Start a prank as a keeper.
        vm.startPrank(keeper);

        // Call setMinOutput with a very high value.
        uint256 minOutput = type(uint256).max;
        strategy.setMinOutput(minOutput);

        // Ensure `tend()` reverts.
        vm.expectRevert();
        strategy.tend();

        // Stop the prank.
        vm.stopPrank();
    }

    // ── minVaultSharePrice ──────────────────────────────────────────────

    /// @dev Tests that `setMinVaultSharePrice` cannot be called by a non-keeper.
    function test_setMinVaultSharePrice_failure_not_keeper() external {
        // Start a prank as a non-keeper address (alice).
        vm.startPrank(alice);

        // setMinVaultSharePrice should revert.
        vm.expectRevert();
        strategy.setMinVaultSharePrice(1);

        // Stop the prank.
        vm.stopPrank();
    }

    /// @dev Tests that `setMinVaultSharePrice` succeeds when called by a keeper.
    function test_setMinVaultSharePrice_suceeds() external {
        // Start a prank as a keeper.
        vm.startPrank(keeper);

        // Call setMinVaultSharePrice with a non-default value.
        uint256 minVaultSharePrice = type(uint256).max;
        strategy.setMinVaultSharePrice(minVaultSharePrice);

        // Ensure the new value is reflected.
        assertEq(minVaultSharePrice, strategy.getMinVaultSharePrice());

        // Stop the prank.
        vm.stopPrank();
    }

    /// @dev Tests that `TendConfig.minVaultSharePrice` is obeyed when opening longs.
    function test_minVaultSharePrice_open_long() external {
        // Deposit into the strategy as alice.
        depositStrategy(MINIMUM_TRANSACTION_AMOUNT + 1, alice);

        // Start a prank as a keeper.
        vm.startPrank(keeper);

        // Call setMinVaultSharePrice with a very high value.
        uint256 minVaultSharePrice = type(uint256).max;
        strategy.setMinVaultSharePrice(minVaultSharePrice);

        // Ensure `tend()` reverts.
        vm.expectRevert();
        strategy.tend();

        // Stop the prank.
        vm.stopPrank();
    }

    // ── positionClosureLimit ────────────────────────────────────────────

    /// @dev Tests that `setPositionClosureLimit` cannot be called by a non-keeper.
    function test_setPositionClosureLimit_failure_not_keeper() external {
        // Start a prank as a non-keeper address (alice).
        vm.startPrank(alice);

        // setPositionClosureLimit should revert.
        vm.expectRevert();
        strategy.setPositionClosureLimit(1);

        // Stop the prank.
        vm.stopPrank();
    }

    /// @dev Tests that `setPositionClosureLimit` succeeds when called by a keeper.
    function test_TendConfig_setPositionClosureLimit_suceeds() external {
        // Start a prank as a keeper.
        vm.startPrank(keeper);

        // Call setPositionClosureLimit with a non-default value.
        uint256 positionClosureLimit = type(uint256).max;
        strategy.setPositionClosureLimit(positionClosureLimit);

        // Ensure the new value is reflected.
        assertEq(positionClosureLimit, strategy.getPositionClosureLimit());

        // Stop the prank.
        vm.stopPrank();
    }

    /// @dev Tests that `TendConfig.positionClosureLimit` is obeyed when calling
    ///      tend().
    function test_positionClosureLimit_tend() external {
        // Deposit into the strategy as alice.
        depositStrategy(MINIMUM_TRANSACTION_AMOUNT + 1, alice);

        // Rebalance to have the strategy hold a single position.
        rebalance();

        // Fast forward a checkpoint duration, deposit, and rebalance.
        // This will result in two total positions held by the strategy.
        advanceTimeWithCheckpoints(CHECKPOINT_DURATION);
        depositStrategy(MINIMUM_TRANSACTION_AMOUNT + 1, alice);
        rebalance();
        assertEq(strategy.positionCount(), 2);

        // Fast forward such that both positions are mature.
        advanceTimeWithCheckpoints(POSITION_DURATION * 2);

        // Start a prank as a keeper.
        vm.startPrank(keeper);

        // Call setPositionClosureLimit with the value 1.
        uint256 positionClosureLimit = 1;
        strategy.setPositionClosureLimit(positionClosureLimit);

        // Call tend().
        strategy.tend();

        // Ensure that the strategy still has a matured position.
        assertTrue(strategy.hasMaturedPositions());

        // Stop the prank.
        vm.stopPrank();
    }

    // ── extraData ───────────────────────────────────────────────────────
    /// @dev Tests that `setExtraData` cannot be called by a non-keeper.
    function test_setExtraData_failure_not_keeper() external {
        // Start a prank as a non-keeper address (alice).
        vm.startPrank(alice);

        // setExtraData should revert.
        vm.expectRevert();
        strategy.setExtraData("hello");

        // Stop the prank.
        vm.stopPrank();
    }

    /// @dev Tests that `setExtraData` succeeds when called by a keeper.
    function test_setExtraData_suceeds() external {
        // Start a prank as a keeper.
        vm.startPrank(keeper);

        // Call setExtraData with a non-default value.
        bytes memory extraData = "hello";
        strategy.setExtraData(extraData);

        // Ensure the new value is reflected.
        assertEq(extraData, strategy.getExtraData());

        // Stop the prank.
        vm.stopPrank();
    }
}
