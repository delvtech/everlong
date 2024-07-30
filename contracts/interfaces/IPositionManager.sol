// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IPositionManager {
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

    /// @notice Emitted when a new position is added to the bond portfolio.
    /// @dev This event will only be emitted with new `maturityTime`s in the portfolio.
    /// TODO: Reconsider naming https://github.com/delvtech/hyperdrive/pull/1096#discussion_r1681337414
    event PositionOpened(
        uint128 indexed maturityTime,
        uint128 bondAmount,
        uint256 index
    );

    /// @notice Emitted when an existing position's `bondAmount` is modified.
    /// TODO: Reconsider naming https://github.com/delvtech/hyperdrive/pull/1096#discussion_r1681337414
    event PositionUpdated(
        uint128 indexed maturityTime,
        uint128 newBondAmount,
        uint256 index
    );

    /// @notice Emitted when an existing position is closed.
    /// TODO: Reconsider naming https://github.com/delvtech/hyperdrive/pull/1096#discussion_r1681337414
    event PositionClosed(uint128 indexed maturityTime);

    /// @notice Emitted when Everlong's underlying portfolio is rebalanced.
    event Rebalanced();

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
}
