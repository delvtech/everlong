// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { EverlongBase } from "../../contracts/internal/EverlongBase.sol";
import { EverlongAdminExposed } from "./EverlongAdminExposed.sol";
import { EverlongERC4626Exposed } from "./EverlongERC4626Exposed.sol";

/// @title EverlongBaseExposed
/// @dev Exposes all internal functions for the `EverlongBase` contract.
abstract contract EverlongBaseExposed is
    EverlongAdminExposed,
    EverlongERC4626Exposed,
    EverlongBase
{}
