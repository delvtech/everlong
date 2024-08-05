// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";
import { EverlongAdminExposed } from "../exposed/EverlongAdminExposed.sol";

/// @title EverlongAdminTest
/// @dev Test harness for EverlongAdmin with exposed internal methods and utility functions.
contract EverlongAdminTest is HyperdriveTest, IEverlongEvents {
    EverlongAdminExposed _everlongAdmin;

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(alice);
        _everlongAdmin = new EverlongAdminExposed(
            "EverlongAdminExposed",
            "EAE",
            address(hyperdrive),
            true
        );
        vm.stopPrank();
    }
}
