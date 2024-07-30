// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { PositionManager } from "../../contracts/PositionManager.sol";
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";

/// @title PositionManagerTest
/// @dev Tests should extend this contract and call its `setUp` function.
contract PositionManagerTest is PositionManager, Test {
    /// @dev Outputs a table of all positions.
    function logPositions() public view {
        console2.log("-- POSITIONS -------------------------------");
        for (uint128 i = 0; i < getPositionCount(); ++i) {
            Position memory p = getPosition(i);
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
        Position memory _position,
        string memory _error
    ) public view {
        Position memory p = getPosition(_index);
        assertEq(_position.maturityTime, p.maturityTime, _error);
        assertEq(_position.bondAmount, p.bondAmount, _error);
    }

    /// @dev Increases block.timestamp to equal the maturity time
    ///      of the most mature (oldest) position.
    function warpToMaturePosition() public {
        // Read the most mature position from the front of the queue.
        Position memory _position = getPosition(0);

        // Return if the oldest position is already mature.
        if (block.timestamp >= _position.maturityTime) return;

        // Set block.timestamp to the oldest position's `maturityTime`.
        vm.warp(_position.maturityTime);
    }

    /// @dev Increases block.timestamp to equal the maturity time
    ///      of the input position.
    /// @param _position Position to mature.
    function warpToMaturePosition(Position memory _position) public {
        // Return if the position is already mature.
        if (block.timestamp >= _position.maturityTime) return;

        // Set block.timestamp to the position's `maturityTime`.
        vm.warp(_position.maturityTime);
    }
}
