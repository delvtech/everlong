// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { EverlongPositionsTest } from "../harnesses/EverlongPositionsTest.sol";
import { IEverlongPositions } from "../../contracts/interfaces/IEverlongPositions.sol";
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";

/// @dev Extend the EverlongPositionsTest contract.
contract TestEverlongPositions is EverlongPositionsTest {
    function setUp() public virtual override {
        super.setUp();
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no positions.
    function test_hasMaturedPositions_false_when_no_positions() external view {
        // Check that `hasMaturedPositions()` returns false
        // when no positions are held.
        assertFalse(
            _everlongPositions.hasMaturedPositions(),
            "should return false when no positions"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns false
    ///      with no mature positions.
    function test_hasMaturedPositions_false_when_no_mature_positions()
        external
    {
        // Open an unmature position.
        _everlongPositions.exposed_handleOpenLong(
            uint128(block.timestamp) + 1,
            5
        );
        console2.log(block.timestamp);

        // Check that `hasMaturedPositions()` returns false.
        assertFalse(
            _everlongPositions.hasMaturedPositions(),
            "should return false when position is newly created"
        );
    }

    /// @dev Validate that `hasMaturedPositions()` returns true
    ///      with a mature position.
    function test_hasMaturedPositions_true_when_single_matured_position()
        external
    {
        // Open unmatured positions with different maturity times.
        _everlongPositions.exposed_handleOpenLong(2, 5);
        _everlongPositions.exposed_handleOpenLong(3, 5);

        // Mature the first position (second will be unmature).
        warpToMaturePosition();

        // Check that `hasMaturedPositions()` returns true.
        assertTrue(
            _everlongPositions.hasMaturedPositions(),
            "should return true with single matured position"
        );
    }

    /// @dev Validate that `hasSufficientExcessLiquidity` returns false
    ///      when Everlong has no balance.
    function test_hasSufficientExcessLiquidity_false_no_balance() external {
        // Check that the contract has no balance.
        assertEq(
            IERC20(_everlongPositions.asset()).balanceOf(
                address(_everlongPositions)
            ),
            0
        );
        // Check that `hasSufficientExcessLiquidity` returns false.
        assertFalse(
            _everlongPositions.hasSufficientExcessLiquidity(),
            "hasSufficientExcessLiquidity should return false with no balance"
        );
    }

    /// @dev Validate that `hasSufficientExcessLiquidity` returns true
    ///      when Everlong has a large balance.
    function test_hasSufficientExcessLiquidity_true_large_balance() external {
        // Mint the contract some tokens.
        uint256 _mintAmount = 5_000_000e18;
        ERC20Mintable(_everlongPositions.asset()).mint(
            address(_everlongPositions),
            _mintAmount
        );

        // Check that the contract has a large balance.
        assertEq(
            IERC20(_everlongPositions.asset()).balanceOf(
                address(_everlongPositions)
            ),
            _mintAmount
        );

        // Check that `hasSufficientExcessLiquidity` returns true.
        assertTrue(
            _everlongPositions.hasSufficientExcessLiquidity(),
            "hasSufficientExcessLiquidity should return false with no balance"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with no preexisting positions.
    function test_exposed_handleOpenLong_no_positions() external {
        // Initial count should be zero.
        console2.log(_everlongPositions.getPositionCount());
        assertEq(
            _everlongPositions.getPositionCount(),
            0,
            "initial position count should be 0"
        );

        // Record an opened position.
        // Check that:
        // - `PositionOpened` event is emitted
        // - Position count is increased
        vm.expectEmit(true, true, true, true);
        emit PositionOpened(1, 1, 0);
        _everlongPositions.exposed_handleOpenLong(1, 1);
        assertEq(
            _everlongPositions.getPositionCount(),
            1,
            "position count should be 1 after opening 1 long"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having distinct maturity times.
    function test_exposed_handleOpenLong_distinct_maturity() external {
        // Record two opened positions with distinct maturity times.
        _everlongPositions.exposed_handleOpenLong(1, 1);
        _everlongPositions.exposed_handleOpenLong(2, 2);

        // Check position count is 2.
        assertEq(
            _everlongPositions.getPositionCount(),
            2,
            "position count should be 2 after opening 2 longs with distinct maturities"
        );

        // Check position order is [(1,1),(2,2)].
        assertPosition(
            0,
            IEverlongPositions.Position(1, 1),
            "position at index 0 should be (1,1) after opening 2 longs with distinct maturities"
        );
        assertPosition(
            1,
            IEverlongPositions.Position(2, 2),
            "position at index 1 should be (2,2) after opening 2 longs with distinct maturities"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with multiple positions having the same maturity time.
    function test_exposed_handleOpenLong_same_maturity() external {
        // Record two opened positions with same maturity times.
        // Check that `PositionUpdated` event is emitted.
        _everlongPositions.exposed_handleOpenLong(1, 1);
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(1, 2, 0);
        _everlongPositions.exposed_handleOpenLong(1, 1);

        // Check position count is 1.
        assertEq(
            _everlongPositions.getPositionCount(),
            1,
            "position count should be 1 after opening 2 longs with same maturity"
        );

        // Check position is now (1,2).
        assertPosition(
            0,
            IEverlongPositions.Position(1, 2),
            "position at index 0 should be (1,2) after opening two longs with same maturity"
        );
    }

    /// @dev Validates `recordOpenedLongs(..)` behavior when called
    ///      with a position with a maturity time sooner than the most
    ///      recently added position's maturity time.
    function test_exposed_handleOpenLong_failure_shorter_maturity() external {
        // Record an opened position.
        _everlongPositions.exposed_handleOpenLong(5, 1);

        // Ensure than recording another position with a lower maturity time
        // results in a revert.
        vm.expectRevert(
            IEverlongPositions.InconsistentPositionMaturity.selector
        );
        _everlongPositions.exposed_handleOpenLong(1, 1);
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with more than the bondAmount of the position.
    function test_exposed_handleCloseLong_failure_greater_amount() external {
        // Record opening and partially closing a long.
        // Check that `PositionUpdated` event is emitted.
        _everlongPositions.exposed_handleOpenLong(1, 2);
        vm.expectRevert(
            IEverlongPositions.InconsistentPositionBondAmount.selector
        );
        _everlongPositions.exposed_handleCloseLong(3);
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with the full bondAmount of the position.
    function test_exposed_handleCloseLong_full_amount() external {
        // Record opening and fully closing a long.
        // Check that `PositionClosed` event is emitted.
        _everlongPositions.exposed_handleOpenLong(1, 1);
        vm.expectEmit(true, true, true, true);
        emit PositionClosed(1);
        _everlongPositions.exposed_handleCloseLong(1);

        // Check position count is 0.
        assertEq(
            _everlongPositions.getPositionCount(),
            0,
            "position count should be 0 after opening and closing a long for the full bond amount"
        );
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with less than the bondAmount of the position.
    function test_exposed_handleCloseLong_partial_amount() external {
        // Record opening and partially closing a long.
        // Check that `PositionUpdated` event is emitted.
        _everlongPositions.exposed_handleOpenLong(1, 2);
        vm.expectEmit(true, true, true, true);
        emit PositionUpdated(1, 1, 0);
        _everlongPositions.exposed_handleCloseLong(1);

        // Check position count is 1.
        assertEq(
            _everlongPositions.getPositionCount(),
            1,
            "position count should be 1 after opening and closing a long for the partial bond amount"
        );
    }
}
