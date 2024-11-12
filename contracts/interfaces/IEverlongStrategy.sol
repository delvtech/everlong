// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";
import { IEverlong } from "./IEverlong.sol";

interface IEverlongStrategy is IStrategy {
    // ╭─────────────────────────────────────────────────────────╮
    // │ VIEW FUNCTIONS                                          │
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
}
