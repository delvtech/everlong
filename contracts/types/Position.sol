// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @notice Tracks the total amount of bonds managed by Everlong
///         with the same maturity.
struct Position {
    /// @notice Time when the position matures.
    uint256 maturity;
    /// @notice Quantity of bonds in the position.
    uint256 quantity;
    /// @notice Vault share price of the Hyperdrive instance before the
    ///         purchase.
    uint256 vaultSharePrice;
}
