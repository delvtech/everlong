// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { EVERLONG_STRATEGY_KIND, EVERLONG_VERSION } from "../../contracts/libraries/Constants.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests Everlong functionality.
contract TestEverlong is EverlongTest {
    /// @dev Ensure that the `hyperdrive()` view function is implemented.
    function test_hyperdrive() external view {
        assertEq(
            strategy.hyperdrive(),
            address(hyperdrive),
            "hyperdrive() should return hyperdrive address"
        );
    }

    /// @dev Ensure that the `kind()` view function is implemented.
    function test_kind() external view {
        assertEq(
            strategy.kind(),
            EVERLONG_STRATEGY_KIND,
            "kind does not match"
        );
    }

    /// @dev Ensure that the `version()` view function is implemented.
    function test_version() external view {
        assertEq(
            strategy.version(),
            EVERLONG_VERSION,
            "version does not match"
        );
    }
}
