// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { EverlongAdmin } from "../../contracts/internal/EverlongAdmin.sol";
import { EverlongBase } from "../../contracts/internal/EverlongBase.sol";

/// @title EverlongAdminExposed
/// @dev Exposes all internal functions for the `EverlongAdmin` contract.
contract EverlongAdminExposed is EverlongAdmin, Test {
    /// @notice Initial configuration paramters for Everlong.
    /// @param hyperdrive_ Address of the Hyperdrive instance wrapped by Everlong.
    /// @param name_ Name of the ERC20 token managed by Everlong.
    /// @param symbol_ Symbol of the ERC20 token managed by Everlong.
    /// @param asBase_ Whether to use Hyperdrive's base token for bond purchases.
    constructor(
        string memory name_,
        string memory symbol_,
        address hyperdrive_,
        bool asBase_
    ) EverlongBase(name_, symbol_, hyperdrive_, asBase_) {}
}
