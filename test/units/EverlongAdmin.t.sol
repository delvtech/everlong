// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";

/// @dev Tests EverlongAdmin functionality.
contract TestEverlongAdmin is EverlongTest {
    /// @dev Validates revert when `setAdmin` called by non-admin.
    function test_setAdmin_failure_unauthorized() external {
        // Ensure that an unauthorized user cannot set the admin address.
        vm.expectRevert(IEverlong.Unauthorized.selector);
        everlong.setAdmin(address(0));
    }

    /// @dev Validates successful `setAdmin` call by current `admin`.
    function test_setAdmin_success_deployer() external {
        // Ensure that the deployer can set the admin address.
        vm.expectEmit(true, true, true, true);
        emit AdminUpdated(alice);
        everlong.setAdmin(alice);
        assertEq(everlong.admin(), alice, "admin address not updated");
    }
}
