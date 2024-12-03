// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";

/// @author DELV
/// @title IPermissionedStrategy
/// @notice Interface for a strategy with the ability to whitelist depositor
///         addresses.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
interface IPermissionedStrategy is IStrategy {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Setters                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Enable or disable deposits to the strategy `_depositor`.
    /// @dev Can only be called by the strategy's `Management` address.
    /// @param _depositor Address to enable/disable deposits for.
    function setDepositor(address _depositor, bool _enabled) external;
}
