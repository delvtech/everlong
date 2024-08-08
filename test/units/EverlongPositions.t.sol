// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Position } from "../../contracts/types/Position.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests for Everlong position management functionality.
contract TestEverlongPositions is EverlongTest {
    function setUp() public virtual override {
        super.setUp();
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no positions.
    function test_hasMaturedPositions_false_when_no_positions() external view {
        // Check that `hasMaturedPositions()` returns false
        // when no positions are held.
        assertFalse(
            everlong.hasMaturedPositions(),
            "should return false when no positions"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no mature positions.
    function test_hasMaturedPositions_false_when_no_mature_positions()
        external
    {
        // Open an unmature position.
        everlong.exposed_handleOpenLong(uint128(block.timestamp) + 1, 5);

        // Check that `hasMaturedPositions()` returns false.
        assertFalse(
            everlong.hasMaturedPositions(),
            "should return false when position is newly created"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns true
    ///      with a mature position.
    function test_hasMaturedPositions_true_when_single_matured_position()
        external
    {
        // Open unmatured positions with different maturity times.
        everlong.exposed_handleOpenLong(2, 5);
        everlong.exposed_handleOpenLong(3, 5);

        // Mature the first position (second will be unmature).
        advanceTime(1, 0);

        // Check that `hasMaturedPositions()` returns true.
        assertTrue(
            everlong.hasMaturedPositions(),
            "should return true with single matured position"
        );
    }

    /// @dev Validate that `hasSufficientExcessLiquidity` returns false
    ///      when Everlong has no balance.
    function test_hasSufficientExcessLiquidity_false_no_balance()
        external
        view
    {
        // Check that the contract has no balance.
        assertEq(IERC20(everlong.asset()).balanceOf(address(everlong)), 0);
        // Check that `hasSufficientExcessLiquidity` returns false.
        assertFalse(
            everlong.hasSufficientExcessLiquidity(),
            "hasSufficientExcessLiquidity should return false with no balance"
        );
    }

    /// @dev Validate that `hasSufficientExcessLiquidity` returns true
    ///      when Everlong has a large balance.
    function test_hasSufficientExcessLiquidity_true_large_balance() external {
        // Mint the contract some tokens.
        uint256 _mintAmount = 5_000_000e18;
        ERC20Mintable(everlong.asset()).mint(address(everlong), _mintAmount);

        // Check that the contract has a large balance.
        assertEq(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            _mintAmount
        );

        // Check that `hasSufficientExcessLiquidity` returns true.
        assertTrue(
            everlong.hasSufficientExcessLiquidity(),
            "hasSufficientExcessLiquidity should return false with no balance"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with no preexisting positions.
    function test_exposed_handleOpenLong_no_positions() external {
        // Initial count should be zero.
        assertEq(
            everlong.getPositionCount(),
            0,
            "initial position count should be 0"
        );

        // Record an opened position.
        // Check that:
        // - `PositionOpened` event is emitted
        // - Position count is increased
        vm.expectEmit(true, true, true, true);
        emit PositionOpened(1, 1, 0);
        everlong.exposed_handleOpenLong(1, 1);
        assertEq(
            everlong.getPositionCount(),
            1,
            "position count should be 1 after opening 1 long"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having distinct maturity times.
    function test_exposed_handleOpenLong_distinct_maturity() external {
        // Record two opened positions with distinct maturity times.
        everlong.exposed_handleOpenLong(1, 1);
        everlong.exposed_handleOpenLong(2, 2);

        // Check position count is 2.
        assertEq(
            everlong.getPositionCount(),
            2,
            "position count should be 2 after opening 2 longs with distinct maturities"
        );

        // Check position order is [(1,1),(2,2)].
        assertPosition(
            0,
            Position({ maturityTime: 1, bondAmount: 1 }),
            "position at index 0 should be (1,1) after opening 2 longs with distinct maturities"
        );
        assertPosition(
            1,
            Position(uint128(2), uint128(2)),
            "position at index 1 should be (2,2) after opening 2 longs with distinct maturities"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having the same maturity time.
    function test_exposed_handleOpenLong_same_maturity() external {
        // Record two opened positions with same maturity times.
        // Check that `PositionUpdated` event is emitted.
        everlong.exposed_handleOpenLong(1, 1);
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(1, 2, 0);
        everlong.exposed_handleOpenLong(1, 1);

        // Check position count is 1.
        assertEq(
            everlong.getPositionCount(),
            1,
            "position count should be 1 after opening 2 longs with same maturity"
        );

        // Check position is now (1,2).
        assertPosition(
            0,
            Position(uint128(1), uint128(2)),
            "position at index 0 should be (1,2) after opening two longs with same maturity"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with a position with a maturity time sooner than the most
    ///      recently added position's maturity time.
    function test_exposed_handleOpenLong_failure_shorter_maturity() external {
        // Record an opened position.
        everlong.exposed_handleOpenLong(5, 1);

        // Ensure than recording another position with a lower maturity time
        // results in a revert.
        vm.expectRevert(IEverlong.InconsistentPositionMaturity.selector);
        everlong.exposed_handleOpenLong(1, 1);
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with more than the bondAmount of the position.
    function test_exposed_handleCloseLong_failure_greater_amount() external {
        // Record opening and partially closing a long.
        // Check that `PositionUpdated` event is emitted.
        everlong.exposed_handleOpenLong(1, 2);
        vm.expectRevert(IEverlong.InconsistentPositionBondAmount.selector);
        everlong.exposed_handleCloseLong(3);
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with the full bondAmount of the position.
    function test_exposed_handleCloseLong_full_amount() external {
        // Record opening and fully closing a long.
        // Check that `PositionClosed` event is emitted.
        everlong.exposed_handleOpenLong(1, 1);
        vm.expectEmit(true, true, true, true);
        emit PositionClosed(1);
        everlong.exposed_handleCloseLong(1);

        // Check position count is 0.
        assertEq(
            everlong.getPositionCount(),
            0,
            "position count should be 0 after opening and closing a long for the full bond amount"
        );
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with less than the bondAmount of the position.
    function test_exposed_handleCloseLong_partial_amount() external {
        // Record opening and partially closing a long.
        // Check that `PositionUpdated` event is emitted.
        everlong.exposed_handleOpenLong(1, 2);
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(1, 1, 0);
        everlong.exposed_handleCloseLong(1);

        // Check position count is 1.
        assertEq(
            everlong.getPositionCount(),
            1,
            "position count should be 1 after opening and closing a long for the partial bond amount"
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
            everlong.getPositionCount(),
            0,
            "everlong should not intialize with positions"
        );
        assertEq(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            0,
            "everlong should not initialize with a balance"
        );
        assertFalse(
            everlong.canRebalance(),
            "cannot rebalance without matured positions or balance"
        );
    }

    /// @dev Ensures that `canRebalance()` returns true with a balance
    ///          greater than Hyperdrive's minTransactionAmount.
    function test_canRebalance_with_balance_over_min_tx_amount() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint some tokens to Everlong for opening longs.
        // Ensure Everlong's balance is gte Hyperdrive's minTransactionAmount.
        // Ensure `canRebalance()` returns true.
        mintApproveEverlongBaseAsset(address(everlong), 100e18);
        assertGe(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            hyperdrive.getPoolConfig().minimumTransactionAmount
        );
        assertTrue(
            everlong.canRebalance(),
            "everlong should be able to rebalance when it has a balance > hyperdrive's minTransactionAmount"
        );
    }

    /// @dev Ensures that `canRebalance()` returns false immediately after
    ///      a rebalance is performed.
    function test_canRebalance_false_after_rebalance() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint some tokens to Everlong for opening Longs.
        // Call `rebalance()` to cause Everlong to open a position.
        // Ensure the `Rebalanced()` event is emitted.
        mintApproveEverlongBaseAsset(address(everlong), 100e18);
        vm.expectEmit(true, true, true, true);
        emit Rebalanced();
        everlong.rebalance();

        // Ensure the position count is now 1.
        // Ensure Everlong's balance is lt Hyperdrive's minTransactionAmount.
        // Ensure `canRebalance()` returns false.
        assertEq(
            everlong.getPositionCount(),
            1,
            "position count after first rebalance with balance should be 1"
        );
        assertLt(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            hyperdrive.getPoolConfig().minimumTransactionAmount,
            "everlong balance after first rebalance should be less than hyperdrive's minTransactionAmount"
        );
        assertFalse(
            everlong.canRebalance(),
            "cannot rebalance without matured positions nor sufficient balance after first rebalance"
        );
    }

    /// @dev Ensures that `canRebalance()` returns true with a matured
    ///      position.
    function test_canRebalance_with_matured_position() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        initialize(alice, fixedRate, contribution);

        // Mint some tokens to Everlong for opening longs and rebalance.
        mintApproveEverlongBaseAsset(address(everlong), 100e18);
        everlong.rebalance();

        // Increase block.timestamp until position is mature.
        // Ensure Everlong has a matured position.
        // Ensure `canRebalance()` returns true.
        advanceTime(everlong.getPosition(0).maturityTime, 0);
        assertTrue(
            everlong.hasMaturedPositions(),
            "everlong should have matured position after advancing time"
        );
        assertTrue(
            everlong.canRebalance(),
            "everlong should allow rebalance with matured position"
        );
    }
}
