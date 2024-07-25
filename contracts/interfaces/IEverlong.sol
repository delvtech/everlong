// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { IAdmin } from "./IAdmin.sol";
import { IPositions } from "./IPositions.sol";

import { IERC4626 } from "openzeppelin/interfaces/IERC4626.sol";

interface IEverlong is IERC4626, IAdmin, IPositions {
    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external pure returns (string memory);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure returns (string memory);
}
