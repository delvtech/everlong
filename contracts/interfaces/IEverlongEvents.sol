// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IEverlongEvents {
    // ── Admin ──────────────────────────────────────────────────

    /// @notice Emitted when admin is transferred.
    event AdminUpdated(address indexed admin);

    // ── Positions ──────────────────────────────────────────────

    /// @notice Emitted when a new position is added to the bond portfolio.
    /// TODO: Reconsider naming https://github.com/delvtech/hyperdrive/pull/1096#discussion_r1681337414
    event PositionOpened(uint128 indexed maturityTime, uint128 bondAmount);

    /// @notice Emitted when an existing position is closed.
    /// TODO: Reconsider naming https://github.com/delvtech/hyperdrive/pull/1096#discussion_r1681337414
    event PositionClosed(uint128 indexed maturityTime, uint128 bondAmount);

    /// @notice Emitted when Everlong's underlying portfolio is rebalanced.
    event Rebalanced();
}
