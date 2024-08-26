// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Positions } from "../../contracts/libraries/Positions.sol";
import { Position } from "../../contracts/types/Position.sol";

/// @dev Tests Positions library functionality.
contract TestPositions is Test {
    using Positions for Positions.PositionQueue;

    Positions.PositionQueue internal positions;

    function setUp() public {
        while (positions.count() > 0) {
            positions.at(0).quantity = 0;
            positions.at(0).maturity = 0;
            positions.at(0).vaultSharePrice = 0;
            positions.popFront();
        }
    }

    function assertPosition(
        uint256 _index,
        Position memory _expected,
        string memory _error
    ) internal {
        Position memory position = positions.at(_index);
        assertEq(
            position.maturity,
            _expected.maturity,
            string.concat(_error, " inequal maturities")
        );
        assertEq(
            position.quantity,
            _expected.quantity,
            string.concat(_error, " inequal quantities")
        );
        assertEq(
            position.vaultSharePrice,
            _expected.vaultSharePrice,
            string.concat(_error, " inequal vaultSharePrices")
        );
    }

    /// @dev Tests that a single position can be successfully opened.
    function test_open_single() external {
        // Open a position.
        positions.open(1, 2, 3);

        // Validate that the position contains the right values.
        assertPosition(0, Position(1, 2, 3), "open single position failed:");
    }

    /// @dev Tests that multiple positions with different maturities can be
    ///      opened.
    function test_open_multiple_different_maturity() external {
        // Open a position.
        positions.open(1, 2, 3);

        // Open another position with a different maturity.
        positions.open(4, 5, 6);

        // Validate that the first position contains the right values.
        assertPosition(
            0,
            Position(1, 2, 3),
            "open multiple different maturity position 0 failed:"
        );

        // Validate that the second position contains the right values.
        assertPosition(
            1,
            Position(4, 5, 6),
            "open multiple different maturity position 1 failed:"
        );
    }

    /// @dev Tests that multiple positions with the same maturity can be
    ///      opened.
    function test_open_multiple_same_maturity() external {
        // Open a position.
        positions.open(1, 2, 3);

        // Open another position with the same maturity.
        positions.open(1, 4, 6);

        // Validate that the position has been updated.
        assertPosition(
            0,
            Position(1, 6, 5),
            "open multiple same maturity failed:"
        );
    }

    /// @dev Tests that a position is correctly closed in full.
    function test_close_full() external {
        // Open a position.
        positions.open(1, 10, 1);

        // Close the position in full.
        positions.close(10);

        // Ensure no positions remain.
        assertEq(
            positions.count(),
            0,
            "close full position failed: 0 positions should be left"
        );
    }

    /// @dev Tests that a position is partially closed correctly.
    function test_close_partial() external {
        // Open a position.
        positions.open(1, 10, 1);

        // Close the position in full.
        positions.close(5);

        // Ensure the remaining portion of the position is correct.
        assertPosition(
            0,
            Position(1, 5, 1),
            "close partial position initial portion failed:"
        );
    }

    /// @dev Tests when back is called with no positions and reverts.
    function test_back_failure_out_of_bounds() external {
        vm.expectRevert(IEverlong.PositionOutOfBounds.selector);
        positions.back();
    }

    /// @dev Tests that back returns the most recently added position.
    function test_back_success() external {
        // Open some positions.
        positions.open(1, 2, 3);
        positions.open(4, 5, 6);
        positions.open(7, 8, 9);

        // Ensure back returns the last position added.
        Position memory p = positions.back();
        assertEq(p.maturity, 7, "back position maturity inequal");
        assertEq(p.quantity, 8, "back position quantity inequal");
        assertEq(p.vaultSharePrice, 9, "back position vaultSharePrice inequal");
    }

    /// @dev Tests when popBack is called with no positions and reverts.
    function test_popBack_failure_empty() external {
        vm.expectRevert(IEverlong.PositionQueueEmpty.selector);
        positions.popBack();
    }

    /// @dev Tests that popBack removes the most recently added position.
    function test_popBack_success() external {
        // Open some positions.
        positions.open(1, 2, 3);
        positions.open(4, 5, 6);
        positions.open(7, 8, 9);

        // Ensure back returns the last position added.
        positions.popBack();
        Position memory p = positions.back();
        assertEq(p.maturity, 4, "popBack position maturity inequal");
        assertEq(p.quantity, 5, "popBack position quantity inequal");
        assertEq(
            p.vaultSharePrice,
            6,
            "popBack position vaultSharePrice inequal"
        );
    }

    /// @dev Tests that pushBack reverts when out of indices.
    function test_pushBack_failure_full() external {
        // Make the beginning index of the queue 1 less than the end.
        positions._begin = 1;

        // Ensure pushBack reverts.
        vm.expectRevert(IEverlong.PositionQueueFull.selector);
        positions.pushBack(Position(type(uint128).max - 1, 1, 1));
    }

    /// @dev Tests that pushBack successfully adds a position to the back of
    ///      the queue.
    function test_pushBack_success() external {
        // Open some positions.
        positions.open(1, 2, 3);
        positions.open(4, 5, 6);

        // Push a position to the back.
        positions.pushBack(Position(7, 8, 9));

        // Ensure the position was correctly pushed to the back.
        assertPosition(2, Position(7, 8, 9), "pushBack failed:");
    }

    // FIXME: function test_front() external {}

    // FIXME: function test_popFront() external {}

    // FIXME: function test_pushFront() external {}

    // FIXME: function test_at() external {}

    // FIXME: function test_empty() external {}

    // FIXME: function test_count() external {}
}
