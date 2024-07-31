// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IEverlongPositions {
    /// @notice Thrown when attempting to insert a position with
    ///         a `maturityTime` sooner than the most recent position's.
    error InconsistentPositionMaturity();

    /// @notice Thrown when attempting to close a position with
    ///         a `bondAmount` greater than that contained by the position.
    error InconsistentPositionBondAmount();

    /// @dev Tracks the total amount of bonds managed by Everlong
    ///      with the same maturityTime.
    struct Position {
        /// @dev Checkpoint time when the position matures.
        uint128 maturityTime;
        /// @dev Quantity of bonds in the position.
        uint128 bondAmount;
    }

    /// @notice Gets the number of positions managed by the Everlong instance.
    /// @return The number of positions.
    function getPositionCount() external view returns (uint256);

    /// @notice Gets the position at an index.
    ///         Position `maturityTime` increases with each index.
    /// @param _index The index of the position.
    /// @return position The position.
    function getPosition(
        uint256 _index
    ) external view returns (Position memory position);

    /// @notice Determines whether any positions are matured.
    /// @return True if any positions are matured, false otherwise.
    function hasMaturedPositions() external view returns (bool);

    /// @notice Determines whether Everlong's portfolio can currently be rebalanced.
    /// @return True if the portfolio can be rebalanced, false otherwise.
    function canRebalance() external view returns (bool);

    /// @notice Rebalances the Everlong bond portfolio if needed.
    function rebalance() external;
}
