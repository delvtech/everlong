// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests for Everlong position management functionality.
contract TestEverlongPositions is EverlongTest {
    using Portfolio for Portfolio.State;

    Portfolio.State public portfolio;

    /// @dev Asserts that the position at the specified index is equal
    ///      to the input `position`.
    /// @param _index Index of the position to compare.
    /// @param _position Input position to validate against
    /// @param _error Message to display for failing assertions.
    function assertPosition(
        uint256 _index,
        IEverlong.Position memory _position,
        string memory _error
    ) public view override {
        IEverlong.Position memory p = portfolio.at(_index);
        assertEq(_position.maturityTime, p.maturityTime, _error);
        assertEq(_position.bondAmount, p.bondAmount, _error);
    }

    function setUp() public virtual override {
        super.setUp();
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
            IEverlong.Position({ maturityTime: 1, bondAmount: 1 }),
            "position at index 0 should be (1,1) after opening 2 longs with distinct maturities"
        );
        assertPosition(
            1,
            IEverlong.Position({ maturityTime: 2, bondAmount: 2 }),
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
            IEverlong.Position(uint128(1), uint128(2)),
            "position at index 0 should be (1,2) after opening two longs with same maturity"
        );
    }

    /// @dev Validates `recordLongsClosed(..)` behavior when
    ///      called with the full bondAmount of the position.
    function test_handleCloseLong_full_amount() external {
        // Record opening and fully closing a long.
        // Check that `PositionClosed` event is emitted.
        portfolio.handleOpenPosition(1, 1);
        console.log("hello");
        portfolio.handleClosePosition();

        // Check position count is 0.
        assertEq(
            portfolio.positionCount(),
            0,
            "position count should be 0 after opening and closing a long for the full bond amount"
        );
    }
}
