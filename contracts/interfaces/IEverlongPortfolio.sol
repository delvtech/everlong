// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IEverlong } from "./IEverlong.sol";

interface IEverlongPortfolio {
    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Rebalances the Everlong bond portfolio if needed.
    function rebalance() external;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Gets the number of positions managed by the Everlong instance.
    /// @return The number of positions.
    function positionCount() external view returns (uint256);

    /// @notice Gets the position at an index.
    ///         Position `maturityTime` increases with each index.
    /// @param _index The index of the position.
    /// @return The position.
    function positionAt(
        uint256 _index
    ) external view returns (IEverlong.Position memory);

    /// @notice Determines whether any positions are matured.
    /// @return True if any positions are matured, false otherwise.
    function hasMaturedPositions() external view returns (bool);

    /// @notice Determines whether Everlong's portfolio can currently be rebalanced.
    /// @return True if the portfolio can be rebalanced, false otherwise.
    function canRebalance() external view returns (bool);
}