// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { VmSafe } from "forge-std/Vm.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Everlong } from "../../contracts/Everlong.sol";

import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";

// TODO: Refactor this to include an instance of `Everlong` with exposed internal functions.
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
                    true,
                    0
                )
            )
        );
    }

    /// @dev Deploy the Everlong instance with custom underlying, name, and symbol.
    function deploy(
        string memory _name,
        string memory _symbol,
        address _underlying,
        bool _asBase,
        uint256 _targetIdleLiquidity
    ) internal {
        everlong = IEverlong(
            address(
                new Everlong(
                    _name,
                    _symbol,
                    address(_underlying),
                    _asBase,
                    _targetIdleLiquidity
                )
            )
        );
    }

    // TODO: This is gross, will refactor
    /// @dev Mint base token to the provided address a
    ///      and approve both the Everlong and Hyperdrive contract.
    function mintApproveHyperdriveBase(
        address recipient,
        uint256 amount
    ) internal {
        ERC20Mintable(hyperdrive.baseToken()).mint(recipient, amount);
        ERC20Mintable(hyperdrive.baseToken()).approve(
            address(everlong),
            type(uint256).max
        );
        ERC20Mintable(hyperdrive.baseToken()).approve(
            address(hyperdrive),
            type(uint256).max
        );
    }

    // TODO: This is gross, will refactor
    /// @dev Mint vault shares token to the provided address a
    ///      and approve both the Everlong and Hyperdrive contract.
    function mintApproveHyperdriveShares(
        address recipient,
        uint256 amount
    ) internal {
        ERC20Mintable(hyperdrive.vaultSharesToken()).mint(recipient, amount);
        ERC20Mintable(hyperdrive.vaultSharesToken()).approve(
            address(everlong),
            amount
        );
    }
}
