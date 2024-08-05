// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { IEverlongAdmin } from "./IEverlongAdmin.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";
import { IEverlongPositions } from "./IEverlongPositions.sol";
import { IERC4626 } from "openzeppelin/interfaces/IERC4626.sol";

interface IEverlong is
    IEverlongAdmin,
    IERC4626,
    IEverlongPositions,
    IEverlongEvents
{
    /// @notice Gets the address of the underlying Hyperdrive Instance
    function hyperdrive() external view returns (address);

    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external pure returns (string memory);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure returns (string memory);
}
