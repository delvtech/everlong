// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { IEverlongStrategy } from "../../../contracts/interfaces/IEverlongStrategy.sol";
import { EverlongStrategy } from "../../../contracts/EverlongStrategy.sol";
import { EVERLONG_STRATEGY_KIND, EVERLONG_VERSION } from "../../../contracts/libraries/Constants.sol";
import { EverlongTest } from "../EverlongTest.sol";

/// @dev Tests Everlong functionality.
contract TestEverlong is EverlongTest {
    /// @dev Ensure that the `hyperdrive()` view function is implemented.
    function test_hyperdrive() external view {
        assertEq(
            IEverlongStrategy(address(strategy)).hyperdrive(),
            address(hyperdrive),
            "hyperdrive() should return hyperdrive address"
        );
    }

    /// @dev Ensure that the `kind()` view function is implemented.
    function test_kind() external view {
        assertEq(
            IEverlongStrategy(address(strategy)).kind(),
            EVERLONG_STRATEGY_KIND,
            "kind does not match"
        );
    }

    /// @dev Ensure that the `version()` view function is implemented.
    function test_version() external view {
        assertEq(
            IEverlongStrategy(address(strategy)).version(),
            EVERLONG_VERSION,
            "version does not match"
        );
    }

    /// @dev Tests that the error `IEverlongStrategy.WrappedBaseMismatch()` is
    ///      thrown when creating a strategy with `isWrapped=true` and
    ///      `asBase=true`.
    function test_wrapped_isbase_true_failure() external {
        vm.expectRevert();
        new EverlongStrategy(
            address(address(asset)),
            "EverlongTest",
            address(hyperdrive),
            true,
            true
        );
    }
}
