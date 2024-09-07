// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { ERC4626 } from "solady/tokens/ERC4626.sol";
import { IEverlongAdmin } from "./IEverlongAdmin.sol";
import { IEverlongEvents } from "./IEverlongEvents.sol";
import { IEverlongPortfolio } from "./IEverlongPortfolio.sol";

abstract contract IEverlong is
    ERC4626,
    IEverlongAdmin,
    IEverlongEvents,
    IEverlongPortfolio
{
    // ╭─────────────────────────────────────────────────────────╮
    // │ Structs                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /**
     * @notice Tracks the total amount of things with stuff.
     */
    struct Position {
        /// @notice Time when the position matures.
        uint128 maturityTime;
        /// @notice Amount of bonds in the position.
        uint128 bondAmount;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Gets the address of the underlying Hyperdrive Instance
    function hyperdrive() external view virtual returns (address);

    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external pure virtual returns (string memory);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure virtual returns (string memory);

    // ╭─────────────────────────────────────────────────────────╮
    // │ Errors                                                  │
    // ╰─────────────────────────────────────────────────────────╯

    // ── Admin ──────────────────────────────────────────────────

    /// @notice Thrown when caller is not the admin.
    error Unauthorized();

    // ── Positions ──────────────────────────────────────────────

    /// @notice Thrown when attempting to insert a position with
    ///         a `maturityTime` sooner than the most recent position's.
    error InconsistentPositionMaturity();

    /// @notice Thrown when attempting to close a position with
    ///         a `bondAmount` greater than that contained by the position.
    error InconsistentPositionBondAmount();

    /// @notice Thrown when a target idle amount is too high to be reached
    ///         even after closing all positions.
    error TargetIdleTooHigh();
}
