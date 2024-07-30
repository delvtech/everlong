// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { Admin } from "../../contracts/Admin.sol";
import { IAdmin } from "../../contracts/interfaces/IAdmin.sol";
import { EverlongTest } from "../harnesses/EverlongTest.t.sol";
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";

/// @dev Extend the `Admin` contract to access the event selectors.
contract EverlongAdminTest is Admin, Test {
    address deployer = address(1);
    IAdmin internal adminContract;

    function setUp() public virtual {
        vm.startPrank(address(1));
        console2.log("hello %s", msg.sender);
        adminContract = new Admin();
        vm.stopPrank();
    }

    /// @dev Validates revert when `setAdmin` called by non-admin.
    function test_setAdmin_revert_unauthorized() external {
        // Ensure that an unauthorized user cannot set the admin address.
        vm.expectRevert(Unauthorized.selector);
        adminContract.setAdmin(address(0));
    }

    /// @dev Validates successful `setAdmin` call by current `admin`.
    function test_setAdmin_success_deployer() external {
        // Ensure that the deployer (address(1)) can set the admin address.
        vm.expectEmit(true, false, false, true);
        emit AdminUpdated(address(0));
        vm.startPrank(deployer);
        adminContract.setAdmin(address(0));
        assertEq(
            adminContract.admin(),
            address(0),
            "admin address not updated"
        );
    }
}
