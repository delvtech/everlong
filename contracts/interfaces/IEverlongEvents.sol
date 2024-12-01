// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IEverlongEvents {
    /// @notice Emitted when a new position is added to the bond portfolio.
    event PositionOpened(uint128 indexed maturityTime, uint128 bondAmount);

    /// @notice Emitted when an existing position is closed.
    event PositionClosed(uint128 indexed maturityTime, uint128 bondAmount);
}
