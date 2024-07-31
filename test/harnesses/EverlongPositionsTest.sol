// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { EverlongPositionsExposed } from "../exposed/EverlongPositionsExposed.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";
import { IEverlongPositions } from "../../contracts/interfaces/IEverlongPositions.sol";
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";

/// @title EverlongPositionsTest
/// @dev Test harness for EverlongPositions with exposed internal methods and utility functions.
contract EverlongPositionsTest is HyperdriveTest, IEverlongEvents {
    EverlongPositionsExposed _everlongPositions;

    function setUp() public virtual override {
        super.setUp();
        _everlongPositions = new EverlongPositionsExposed(
            "EverlongPositionsExposed",
            "EPE",
            address(hyperdrive),
            true
        );
    }

    /// @dev Outputs a table of all positions.
    function logPositions() public view {
        console2.log("-- POSITIONS -------------------------------");
        for (uint128 i = 0; i < _everlongPositions.getPositionCount(); ++i) {
            IEverlongPositions.Position memory p = _everlongPositions
                .getPosition(i);
            console2.log(
                "index: %s - maturityTime: %s - bondAmount: %s",
                i,
                p.maturityTime,
                p.bondAmount
            );
        }
        console2.log("--------------------------------------------");
    }

    /// @dev Asserts that the position at the specified index is equal
    ///      to the input `position`.
    /// @param _index Index of the position to compare.
    /// @param _position Input position to validate against
    /// @param _error Message to display for failing assertions.
    function assertPosition(
        uint256 _index,
        IEverlongPositions.Position memory _position,
        string memory _error
    ) public view {
        IEverlongPositions.Position memory p = _everlongPositions.getPosition(
            _index
        );
        assertEq(_position.maturityTime, p.maturityTime, _error);
        assertEq(_position.bondAmount, p.bondAmount, _error);
    }

    /// @dev Increases block.timestamp to equal the maturity time
    ///      of the most mature (oldest) position.
    function warpToMaturePosition() public {
        // Read the most mature position from the front of the queue.
        IEverlongPositions.Position memory _position = _everlongPositions
            .getPosition(0);

        // Return if the oldest position is already mature.
        if (block.timestamp >= _position.maturityTime) return;

        // Set block.timestamp to the oldest position's `maturityTime`.
        vm.warp(_position.maturityTime);
    }

    /// @dev Increases block.timestamp to equal the maturity time
    ///      of the input position.
    /// @param _position Position to mature.
    function warpToMaturePosition(
        IEverlongPositions.Position memory _position
    ) public {
        // Return if the position is already mature.
        if (block.timestamp >= _position.maturityTime) return;

        // Set block.timestamp to the position's `maturityTime`.
        vm.warp(_position.maturityTime);
    }
}
