// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Everlong } from "../../contracts/Everlong.sol";
import { EverlongAdminExposed } from "./EverlongAdminExposed.sol";
import { EverlongERC4626Exposed } from "./EverlongERC4626Exposed.sol";
import { EverlongPortfolioExposed } from "./EverlongPortfolioExposed.sol";
import { EverlongPositionsExposed } from "./EverlongPositionsExposed.sol";

/// @title EverlongExposed
/// @dev Exposes all internal functions for the `Everlong` contract.
contract EverlongExposed is
    EverlongAdminExposed,
    EverlongERC4626Exposed,
    EverlongPositionsExposed,
    EverlongPortfolioExposed,
    Everlong,
    Test
{
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
    ) Everlong(name_, symbol_, hyperdrive_, asBase_) {}
}
