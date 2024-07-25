// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { VmSafe } from "forge-std/Vm.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Everlong } from "../../contracts/Everlong.sol";

/// @dev Everlong testing harness contract.
/// @dev Tests should extend this contract and call its `setUp` function.
contract EverlongTest is HyperdriveTest {
    // ── Hyperdrive Storage ──────────────────────────────────────────────
    // address alice
    // address bob
    // address celine
    // address dan
    // address eve
    //
    // address minter
    // address deployer
    // address feeCollector
    // address sweepCollector
    // address governance
    // address pauser
    // address registrar
    // address rewardSource
    //
    // ERC20ForwarderFactory         forwarderFactory
    // ERC20Mintable                 baseToken
    // IHyperdriveGovernedRegistry   registry
    // IHyperdriveCheckpointRewarder checkpointRewarder
    // IHyperdrive                   hyperdrive

    /// @dev Everlong instance to test.
    IEverlong internal everlong;

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(alice);
        deploy();
    }

    string internal constant DEFAULT_NAME = "Everlong Test";
    string internal constant DEFAULT_SYMBOL = "ETEST";

    /// @dev Deploy the Everlong instance with default underlying, name, and symbol.
    function deploy() internal {
        everlong = IEverlong(
            address(
                new Everlong(
                    "Everlong Test",
                    "ETEST",
                    address(hyperdrive),
                    hyperdrive.vaultSharesToken()
                )
            )
        );
    }

    /// @dev Deploy the Everlong instance with custom underlying, name, and symbol.
    function deploy(
        string memory name,
        string memory symbol,
        address underlying,
        address asset
    ) internal {
        everlong = IEverlong(
            address(new Everlong(name, symbol, address(underlying), asset))
        );
    }
}
