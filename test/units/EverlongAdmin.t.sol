// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { EverlongAdminTest } from "../harnesses/EverlongAdminTest.sol";
import { EverlongAdminExposed } from "../exposed/EverlongAdminExposed.sol";
import { EverlongAdmin } from "../../contracts/internal/EverlongAdmin.sol";
import { IEverlongAdmin } from "../../contracts/interfaces/IEverlongAdmin.sol";

/// @dev Tests EverlongAdmin functionality.
contract TestEverlongAdmin is EverlongAdminTest {
    function setUp() public virtual override {
        super.setUp();
    }

    /// @dev Validates revert when `setAdmin` called by non-admin.
    function test_setAdmin_failure_unauthorized() external {
        // Ensure that an unauthorized user cannot set the admin address.
        vm.expectRevert(IEverlongAdmin.Unauthorized.selector);
        _everlongAdmin.setAdmin(address(0));
    }

    /// @dev Validates successful `setAdmin` call by current `admin`.
    function test_setAdmin_success_deployer() external {
        // Ensure that the deployer (address(1)) can set the admin address.
        vm.expectEmit(true, false, false, true);
        emit AdminUpdated(address(0));
        vm.startPrank(alice);
        _everlongAdmin.setAdmin(address(0));
        assertEq(
            _everlongAdmin.admin(),
            address(0),
            "admin address not updated"
        );
    }
}
