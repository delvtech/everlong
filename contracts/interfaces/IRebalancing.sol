// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IRebalancing {
    /// @notice Emitted when Everlong's underlying portfolio is rebalanced.
    event Rebalanced();

    /// @notice Determines whether Everlong's portfolio can currently be rebalanced.
    /// @return True if the portfolio can be rebalanced, false otherwise.
    function canRebalance() external view returns (bool);

    /// @notice Rebalances the Everlong bond portfolio if needed.
    function rebalance() external;
}
