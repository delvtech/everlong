// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { EverlongTest } from "../harnesses/EverlongTest.t.sol";

/// @dev Extend only the test harness.
contract IEverlongTest is EverlongTest {
    /// @dev Ensure that the `kind()` view function is implemented.
    function test_view_kind() external view {
        vm.assertNotEq(everlong.kind(), "", "kind is empty string");
    }

    /// @dev Ensure that the `version()` view function is implemented.
    function test_view_version() external view {
        vm.assertNotEq(everlong.version(), "", "version is empty string");
    }
}
