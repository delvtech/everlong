// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { VmSafe } from "forge-std/Vm.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Everlong } from "../../contracts/Everlong.sol";

contract EverlongTest is HyperdriveTest {
    IEverlong internal everlong;

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(alice);
        deploy();
    }

    /// @dev Deploy the Everlong instance with default underlying, name, and symbol.
    function deploy() internal {
        everlong = IEverlong(
            address(new Everlong("Everlong Test", "ETEST", address(hyperdrive)))
        );
    }

    /// @dev Deploy the Everlong instance with custom underlying, name, and symbol.
    function deploy(
        string memory name,
        string memory symbol,
        address underlying
    ) internal {
        everlong = IEverlong(
            address(new Everlong(name, symbol, address(underlying)))
        );
    }
}
