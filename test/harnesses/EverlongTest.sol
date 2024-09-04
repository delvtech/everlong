// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { EverlongExposed } from "../exposed/EverlongExposed.sol";

// TODO: Refactor this to include an instance of `Everlong` with exposed internal functions.
/// @dev Everlong testing harness contract.
/// @dev Tests should extend this contract and call its `setUp` function.
contract EverlongTest is HyperdriveTest, IEverlongEvents {
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
    EverlongExposed internal everlong;

    /// @dev Everlong token name.
    string internal EVERLONG_NAME = "Everlong Testing";

    /// @dev Everlong token symbol.
    string internal EVERLONG_SYMBOL = "evTest";

    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(deployer);
        deploy();
        vm.stopPrank();
    }

    /// @dev Deploy the Everlong instance with default underlying, name, and symbol.
    function deploy() internal {
        everlong = new EverlongExposed(
            EVERLONG_NAME,
            EVERLONG_SYMBOL,
            18,
            address(hyperdrive),
            true
        );
    }

    /// @dev Deploy the Everlong instance with custom underlying, name, and symbol.
    function deploy(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _underlying,
        bool _asBase
    ) internal {
        everlong = new EverlongExposed(
            _name,
            _symbol,
            _decimals,
            address(_underlying),
            _asBase
        );
    }

    // TODO: This is gross, will refactor
    /// @dev Mint base token to the provided address a
    ///      and approve the Everlong contract.
    function mintApproveEverlongBaseAsset(
        address recipient,
        uint256 amount
    ) internal {
        ERC20Mintable(hyperdrive.baseToken()).mint(recipient, amount);
        vm.startPrank(recipient);
        ERC20Mintable(hyperdrive.baseToken()).approve(
            address(everlong),
            amount
        );
        vm.stopPrank();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Positions                                               │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Outputs a table of all positions.
    function logPositions() public view {
        /* solhint-disable no-console */
        console.log("-- POSITIONS -------------------------------");
        for (uint128 i = 0; i < everlong.positionCount(); ++i) {
            IEverlong.Position memory p = everlong.positionAt(i);
            console.log(
                "index: %s - maturityTime: %s - bondAmount: %s",
                i,
                p.maturityTime,
                p.bondAmount
            );
        }
        console.log("--------------------------------------------");
        /* solhint-enable no-console */
    }

    /// @dev Asserts that the position at the specified index is equal
    ///      to the input `position`.
    /// @param _index Index of the position to compare.
    /// @param _position Input position to validate against
    /// @param _error Message to display for failing assertions.
    function assertPosition(
        uint256 _index,
        IEverlong.Position memory _position,
        string memory _error
    ) public view virtual {
        IEverlong.Position memory p = everlong.positionAt(_index);
        assertEq(_position.maturityTime, p.maturityTime, _error);
        assertEq(_position.bondAmount, p.bondAmount, _error);
    }
}
