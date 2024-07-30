// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { IAdmin } from "../../contracts/interfaces/IAdmin.sol";
import { Admin } from "../../contracts/Admin.sol";
import { EverlongTest } from "../harnesses/EverlongTest.t.sol";

/// @dev Extend the `Admin` contract to access the event selectors.
contract EverlongAdminTest is EverlongTest, Admin {
    /// @dev Validates revert when `setAdmin` called by non-admin.
    function test_setAdmin_revert_unauthorized() external {
        // Ensure that an unauthorized user cannot set the admin address.
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert(IAdmin.Unauthorized.selector);
        everlong.setAdmin(address(0));
    }

    /// @dev Validates successful `setAdmin` call by current `admin`.
    function test_setAdmin_success_deployer() external {
        // Ensure that the deployer can set the admin address.
        vm.expectEmit(true, false, false, true);
        emit AdminUpdated(address(0));
        everlong.setAdmin(address(0));
        assertEq(everlong.admin(), address(0), "admin address not updated");
    }
}
