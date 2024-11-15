// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests for Everlong position management functionality.
contract TestEverlongPortfolio is EverlongTest {
    using Portfolio for Portfolio.State;

    Portfolio.State public portfolio;

    /// @dev Asserts that the position at the specified index is equal
    ///      to the input `position`.
    /// @param _index Index of the position to compare.
    /// @param _position Input position to validate against
    /// @param _error Message to display for failing assertions.
    function assertPosition(
        uint256 _index,
        IEverlongStrategy.Position memory _position,
        string memory _error
    ) public view {
        IEverlongStrategy.Position memory p = portfolio.at(_index);
        assertEq(_position.maturityTime, p.maturityTime, _error);
        assertEq(_position.bondAmount, p.bondAmount, _error);
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with no preexisting positions.
    function test_handleOpenLong_no_positions() external {
        // Initial count should be zero.
        assertEq(
            portfolio.positionCount(),
            0,
            "initial position count should be 0"
        );

        // Record an opened position.
        // Check that position count is increased
        portfolio.handleOpenPosition(1, 1);
        assertEq(
            portfolio.positionCount(),
            1,
            "position count should be 1 after opening 1 long"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having distinct maturity times.
    function test_handleOpenLong_distinct_maturity() external {
        // Record two opened positions with distinct maturity times.
        portfolio.handleOpenPosition(1, 1);
        portfolio.handleOpenPosition(2, 2);

        // Check position count is 2.
        assertEq(
            portfolio.positionCount(),
            2,
            "position count should be 2 after opening 2 longs with distinct maturities"
        );

        // Check position order is [(1,1),(2,2)].
        assertPosition(
            0,
            IEverlongStrategy.Position({ maturityTime: 1, bondAmount: 1 }),
            "position at index 0 should be (1,1) after opening 2 longs with distinct maturities"
        );
        assertPosition(
            1,
            IEverlongStrategy.Position({ maturityTime: 2, bondAmount: 2 }),
            "position at index 1 should be (2,2) after opening 2 longs with distinct maturities"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having the same maturity time.
    function test_handleOpenLong_same_maturity() external {
        // Record two opened positions with same maturity times.
        // Check that `PositionUpdated` event is emitted.
        portfolio.handleOpenPosition(1, 1);
        portfolio.handleOpenPosition(1, 1);

        // Check position count is 1.
        assertEq(
            portfolio.positionCount(),
            1,
            "position count should be 1 after opening 2 longs with same maturity"
        );

        // Check position is now (1,2).
        assertPosition(
            0,
            IEverlongStrategy.Position(uint128(1), uint128(2)),
            "position at index 0 should be (1,2) after opening two longs with same maturity"
        );
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with the full bondAmount of the position.
    function test_handleCloseLong_full_amount() external {
        // Record opening and fully closing a long.
        // Check that `PositionClosed` event is emitted.
        portfolio.handleOpenPosition(1, 1);
        portfolio.handleClosePosition();

        // Check position count is 0.
        assertEq(
            portfolio.positionCount(),
            0,
            "position count should be 0 after opening and closing a long for the full bond amount"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no positions.
    function test_hasMaturedPositions_false_when_no_positions() external view {
        // Check that `hasMaturedPositions()` returns false
        // when no positions are held.
        assertFalse(
            strategy.hasMaturedPositions(),
            "should return false when no positions"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no mature positions.
    function test_hasMaturedPositions_false_when_no_mature_positions()
        external
    {
        // Open an unmature position.
        portfolio.handleOpenPosition(block.timestamp + 1, 5);

        // Check that `hasMaturedPositions()` returns false.
        assertFalse(
            strategy.hasMaturedPositions(),
            "should return false when position is newly created"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns true
    ///      with a mature position.
    function test_hasMaturedPositions_true_when_single_matured_position()
        external
    {
        // Open unmatured positions with different maturity times.
        portfolio.handleOpenPosition(block.timestamp + 2, 5);
        portfolio.handleOpenPosition(
            block.timestamp * 2 * POSITION_DURATION,
            5
        );

        // Check that `hasMaturedPositions()` returns false.
        assertFalse(
            strategy.hasMaturedPositions(),
            "should return false with single matured position"
        );

        // Mature the first position (second will be unmature).
        advanceTimeWithCheckpoints(POSITION_DURATION);

        // Check that `hasMaturedPositions()` returns true.
        assertTrue(
            strategy.hasMaturedPositions(),
            "should return true with single matured position"
        );
    }

    /// @dev Ensure that `canRebalance()` returns false when everlong has
    ///      no positions nor balance.
    function test_canRebalance_false_no_positions_no_balance() external view {
        // Check that Everlong:
        // - has no positions
        // - has no balance
        // - `canRebalance()` returns false
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
        assertFalse(
            strategy.canRebalance(),
            "cannot rebalance without matured positions or balance"
        );
    }

    /// @dev Ensures that `canRebalance()` returns true with a balance
    ///          greater than Hyperdrive's minTransactionAmount.
    function test_canRebalance_with_balance_over_min_tx_amount() external {
        // Mint some tokens to Everlong for opening longs.
        // Ensure Everlong's balance is gte Hyperdrive's minTransactionAmount.
        // Ensure `canRebalance()` returns true.
        mintApproveEverlongBaseAsset(address(vault), 100e18);
        assertGe(
            IERC20(vault.asset()).balanceOf(address(vault)),
            hyperdrive.getPoolConfig().minimumTransactionAmount
        );
        assertTrue(
            strategy.canRebalance(),
            "everlong should be able to rebalance when it has a balance > hyperdrive's minTransactionAmount"
        );
    }

    /// @dev Ensures that `canRebalance()` returns true with a matured
    ///      position.
    function test_canRebalance_with_matured_position() external {
        // Mint some tokens to Everlong for opening longs and rebalance.
        mintApproveEverlongBaseAsset(address(vault), 100e18);
        rebalance();

        // Increase block.timestamp until position is mature.
        // Ensure Everlong has a matured position.
        // Ensure `canRebalance()` returns true.
        advanceTimeWithCheckpoints(strategy.positionAt(0).maturityTime);
        assertTrue(
            strategy.hasMaturedPositions(),
            "everlong should have matured position after advancing time"
        );
        assertTrue(
            strategy.canRebalance(),
            "everlong should allow rebalance with matured position"
        );
    }

    /// @dev Ensures that rebalance reverts when called by a non-admin
    // function test_rebalance_failure_unauthorized() external {
    //     // Attempt calling rebalance as Dan (not the admin).
    //     vm.startPrank(dan);
    //     vm.expectRevert(IEverlong.Unauthorized.selector);
    //     vault.rebalance(DEFAULT_REBALANCE_OPTIONS);
    //     vm.stopPrank();
    // }

    // TODO: Reduce tolerance on remaining idle liquidity.
    //
    /// @dev Ensures the following after a rebalance:
    ///      1. Idle liquidity is close to target.
    ///      2. Idle liquidity is not over max.
    ///      3. No matured positions are held.
    function test_rebalance_state() external {
        // Mint some tokens to Everlong for opening longs and rebalance.
        mintApproveEverlongBaseAsset(address(vault), 10_000e18);
        rebalance();
        advanceTimeWithCheckpointsAndRebalancing(
            strategy.positionAt(0).maturityTime
        );
        rebalance();

        // Ensure idle liquidity is close to target.
        assertApproxEqAbs(
            IERC20(vault.asset()).balanceOf(address(vault)),
            targetIdleLiquidity(),
            targetIdleLiquidity() / 10
        );

        // Ensure idle liquidity is not over max.
        assertLt(
            IERC20(vault.asset()).balanceOf(address(vault)),
            minIdleLiquidity()
        );

        // Ensure no matured positions
        assertFalse(strategy.hasMaturedPositions());
    }

    /// @dev Tests the functionality of `RebalanceOptions.positionClosureLimit`.
    function test_rebalance_options_positionClosureLimit() external {
        // Create three positions in Everlong.
        mintApproveEverlongBaseAsset(address(vault), 10_000e18);
        rebalance();
        advanceTimeWithCheckpoints(POSITION_DURATION / 10);
        mintApproveEverlongBaseAsset(address(vault), 10_000e18);
        rebalance();
        advanceTimeWithCheckpoints(POSITION_DURATION / 10);
        mintApproveEverlongBaseAsset(address(vault), 10_000e18);
        rebalance();
        advanceTimeWithCheckpoints(POSITION_DURATION / 10);

        // Fast forward time so they are all mature.
        advanceTimeWithCheckpoints(POSITION_DURATION * 2);

        // Ensure that Everlong has 3 mature positions.
        assertEq(strategy.positionCount(), 3);
        assertTrue(strategy.positionAt(0).maturityTime < block.timestamp);
        assertTrue(strategy.positionAt(1).maturityTime < block.timestamp);
        assertTrue(strategy.positionAt(2).maturityTime < block.timestamp);

        // Call rebalance with `positionClosureLimit` set to one.
        rebalance(
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 1,
                extraData: ""
            })
        );

        // Ensure that Everlong still has 3 positions, the first 2 mature.
        assertEq(strategy.positionCount(), 3);
        assertTrue(strategy.positionAt(0).maturityTime < block.timestamp);
        assertTrue(strategy.positionAt(1).maturityTime < block.timestamp);
        assertTrue(strategy.positionAt(2).maturityTime > block.timestamp);
    }

    /// @dev Tests the functionality of `RebalanceOptions.spendingLimit`.
    function test_rebalance_options_spendingLimit() external {
        // Mint Everlong some assets.
        mintApproveEverlongBaseAsset(address(vault), 10_000e18);

        // Try rebalancing with too low of a `spendingLimit`. No positions
        // should be created.
        rebalance(
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 1,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        assertEq(strategy.positionCount(), 0);

        // Try rebalancing with too high of a `spendingLimit`. A position should
        // be created and idle liquidity should be within 1% of target.
        uint256 targetIdle = targetIdleLiquidity();
        rebalance(
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: type(uint256).max,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        uint256 balance = IERC20(vault.asset()).balanceOf(address(vault));
        assertEq(strategy.positionCount(), 1);
        assertApproxEqRel(balance, targetIdle, 0.01e18);
    }

    /// @dev Tests the functionality of `RebalanceOptions.minOutput`.
    function test_rebalance_options_minOutput() external {
        // Mint Everlong some assets.
        mintApproveEverlongBaseAsset(address(vault), 10_000e18);

        // Rebalancing with an incredibly high `minOutput` should fail.
        vm.expectRevert();
        strategy.rebalance(
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 0,
                minOutput: type(uint256).max,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
    }

    /// @dev Tests the functionality of `RebalanceOptions.minVaultSharePrice`.
    function test_rebalance_options_minVaultSharePrice() external {
        // Mint Everlong some assets.
        mintApproveEverlongBaseAsset(address(vault), 10_000e18);

        // Rebalancing with an incredibly high `minVaultSharePrice` should fail.
        vm.expectRevert();
        rebalance(
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: type(uint256).max,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
    }
}
