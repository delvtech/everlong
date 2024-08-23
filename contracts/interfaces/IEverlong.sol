// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IERC4626 } from "openzeppelin/interfaces/IERC4626.sol";
import { IEverlongAdmin } from "./IEverlongAdmin.sol";
import { IEverlongEvents } from "./IEverlongEvents.sol";
import { IEverlongPositions } from "./IEverlongPositions.sol";

interface IEverlong is
    IEverlongAdmin,
    IERC4626,
    IEverlongEvents,
    IEverlongPositions
{
    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Gets the address of the underlying Hyperdrive Instance
    function hyperdrive() external view returns (address);

    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external pure returns (string memory);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure returns (string memory);

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
