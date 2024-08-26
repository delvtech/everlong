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

    /// @notice Thrown when attempting to retrieve a nonexistent position from
    ///         the PositionQueue.
    error PositionOutOfBounds();

    /// @notice Thrown when attempting to remove a position from an empty
    ///         PositionQueue.
    error PositionQueueEmpty();

    /// @notice Thrown when the PositionQueue has run out of indices to store
    ///         positions.
    error PositionQueueFull();

    /// @notice Thrown when a target idle amount is too high to be reached
    ///         even after closing all positions.
    error TargetIdleTooHigh();
}
