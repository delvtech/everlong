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

    uint256 internal TARGET_IDLE_LIQUIDITY_PERCENTAGE = 0.1e18;
    uint256 internal MAX_IDLE_LIQUIDITY_PERCENTAGE = 0.2e18;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Hyperdrive Configuration                                │
    // ╰─────────────────────────────────────────────────────────╯

    address internal HYPERDRIVE_INITIALIZER = address(0);

    uint256 internal FIXED_RATE = 0.05e18;
    int256 internal VARIABLE_RATE = 0.10e18;

    uint256 internal INITIAL_VAULT_SHARE_PRICE = 1e18;
    uint256 internal INITIAL_CONTRIBUTION = 2_000_000e18;

    uint256 internal CURVE_FEE = 0.01e18;
    uint256 internal FLAT_FEE = 0.0005e18;
    uint256 internal GOVERNANCE_LP_FEE = 0.15e18;
    uint256 internal GOVERNANCE_ZOMBIE_FEE = 0.03e18;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Deploy Helpers                                          │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Deploy the Everlong instance with default underlying, name,
    ///      and symbol.
    function deployEverlong() internal {
        // Deploy the hyperdrive instance.
        deploy(
            deployer,
            FIXED_RATE,
            INITIAL_VAULT_SHARE_PRICE,
            CURVE_FEE,
            FLAT_FEE,
            GOVERNANCE_LP_FEE,
            GOVERNANCE_ZOMBIE_FEE
        );

        // Seed liquidity for the hyperdrive instance.
        if (HYPERDRIVE_INITIALIZER == address(0)) {
            HYPERDRIVE_INITIALIZER = deployer;
        }
        initialize(HYPERDRIVE_INITIALIZER, FIXED_RATE, INITIAL_CONTRIBUTION);

        vm.startPrank(deployer);
        everlong = new EverlongExposed(
            EVERLONG_NAME,
            EVERLONG_SYMBOL,
            hyperdrive.decimals(),
            address(hyperdrive),
            true,
            TARGET_IDLE_LIQUIDITY_PERCENTAGE,
            MAX_IDLE_LIQUIDITY_PERCENTAGE
        );
        vm.stopPrank();

        // Fast forward and accrue some interest.
        advanceTimeWithCheckpoints(POSITION_DURATION * 2, VARIABLE_RATE);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Deposit Helpers                                         │
    // ╰─────────────────────────────────────────────────────────╯

    function depositEverlong(
        uint256 _amount,
        address _depositor
    ) internal returns (uint256 shares) {
        // Resolve the appropriate token.
        ERC20Mintable token = ERC20Mintable(everlong.asset());

        // Mint sufficient tokens to _depositor.
        vm.startPrank(_depositor);
        token.mint(_amount);
        vm.stopPrank();

        // Approve everlong as _depositor.
        vm.startPrank(_depositor);
        token.approve(address(everlong), _amount);
        vm.stopPrank();

        // Make the deposit.
        vm.startPrank(_depositor);
        shares = everlong.deposit(_amount, _depositor);
        vm.stopPrank();

        // Return the amount of shares issued to _depositor for the deposit.
        return shares;
    }

    function redeemEverlong(
        uint256 _amount,
        address _redeemer
    ) internal returns (uint256 proceeds) {
        // Make the redemption.
        vm.startPrank(_redeemer);
        proceeds = everlong.redeem(_amount, _redeemer, _redeemer);
        vm.stopPrank();
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
