// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { PositionManagerTest } from "../harnesses/PositionManagerTest.sol";
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";

/// @dev Extend the PositionManager contract.
contract EverlongPositionManagerTest is PositionManagerTest {
    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with no preexisting positions.
    function test__recordLongsOpened_no_positions() external {
        // Initial count should be zero.
        console2.log(getPositionCount());
        assertEq(getPositionCount(), 0, "initial position count should be 0");

        // Record an opened position.
        // Check that:
        // - `PositionOpened` event is emitted
        // - Position count is increased
        vm.expectEmit(true, true, true, true);
        emit PositionOpened(1, 1, 0);
        _recordLongsOpened(1, 1);
        assertEq(
            getPositionCount(),
            1,
            "position count should be 1 after opening 1 long"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having distinct maturity times.
    function test__recordLongsOpened_distinct_maturity() external {
        // Record two opened positions with distinct maturity times.
        _recordLongsOpened(1, 1);
        _recordLongsOpened(2, 2);

        // Check position count is 2.
        assertEq(
            getPositionCount(),
            2,
            "position count should be 2 after opening 2 longs with distinct maturities"
        );

        // Check position order is [(1,1),(2,2)].
        assertPosition(
            0,
            Position(1, 1),
            "position at index 0 should be (1,1) after opening 2 longs with distinct maturities"
        );
        assertPosition(
            1,
            Position(2, 2),
            "position at index 1 should be (2,2) after opening 2 longs with distinct maturities"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having the same maturity time.
    function test__recordLongsOpened_same_maturity() external {
        // Record two opened positions with same maturity times.
        // Check that `PositionUpdated` event is emitted.
        _recordLongsOpened(1, 1);
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(1, 2, 0);
        _recordLongsOpened(1, 1);

        // Check position count is 1.
        assertEq(
            getPositionCount(),
            1,
            "position count should be 1 after opening 2 longs with same maturity"
        );

        // Check position is now (1,2).
        assertPosition(
            0,
            Position(1, 2),
            "position at index 0 should be (1,2) after opening two longs with same maturity"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with a position with a maturity time sooner than the most
    ///      recently added position's maturity time.
    function test__recordLongsOpened_shorter_maturity() external {
        // Record an opened position.
        _recordLongsOpened(5, 1);

        // Ensure than recording another position with a lower maturity time
        // results in a revert.
        vm.expectRevert(InconsistentPositionMaturity.selector);
        _recordLongsOpened(1, 1);
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with the full bondAmount of the position.
    function test__recordLongsClosed_full_amount() external {
        // Record opening and fully closing a long.
        // Check that `PositionClosed` event is emitted.
        _recordLongsOpened(1, 1);
        vm.expectEmit(true, true, true, true);
        emit PositionClosed(1);
        _recordLongsClosed(1);

        // Check position count is 0.
        assertEq(
            getPositionCount(),
            0,
            "position count should be 0 after opening and closing a long for the full bond amount"
        );
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with less than the bondAmount of the position.
    function test__recordLongsClosed_partial_amount() external {
        // Record opening and partially closing a long.
        // Check that `PositionUpdated` event is emitted.
        _recordLongsOpened(1, 2);
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(1, 1, 0);
        _recordLongsClosed(1);

        // Check position count is 1.
        assertEq(
            getPositionCount(),
            1,
            "position count should be 1 after opening and closing a long for the partial bond amount"
        );
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with more than the bondAmount of the position.
    function test__recordLongsClosed_greater_amount() external {
        // Record opening and partially closing a long.
        // Check that `PositionUpdated` event is emitted.
        _recordLongsOpened(1, 2);
        vm.expectRevert(InconsistentPositionBondAmount.selector);
        _recordLongsClosed(3);
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no positions.
    function test_hasMaturedPositions_false_when_no_positions() external view {
        // Check that `hasMaturedPositions()` returns false
        // when no positions are held.
        assertFalse(
            hasMaturedPositions(),
            "should return false when no positions"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no mature positions.
    function test_hasMaturedPositions_false_when_no_mature_positions()
        external
    {
        // Open an unmature position.
        _recordLongsOpened(2, 5);

        // Check that `hasMaturedPositions()` returns false.
        assertFalse(
            hasMaturedPositions(),
            "should return false when position is newly created"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns true
    ///      with a mature position.
    function test_hasMaturedPositions_true_when_single_matured_position()
        external
    {
        // Open unmatured positions with different maturity times.
        _recordLongsOpened(2, 5);
        _recordLongsOpened(3, 5);

        // Mature the first position (second will be unmature).
        warpToMaturePosition();

        // Check that `hasMaturedPositions()` returns true.
        assertTrue(
            hasMaturedPositions(),
            "should return true with single matured position"
        );
    }
}
