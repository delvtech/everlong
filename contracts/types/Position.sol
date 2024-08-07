// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

/// @notice Tracks the total amount of bonds managed by Everlong
///      with the same maturityTime.
struct Position {
    /// @notice Checkpoint time when the position matures.
    uint128 maturityTime;
    /// @notice Quantity of bonds in the position.
    uint128 bondAmount;
}
