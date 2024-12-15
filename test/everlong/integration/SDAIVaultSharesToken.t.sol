// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { IERC20, IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { IVault } from "yearn-vaults-v3/interfaces/IVault.sol";
import { IPermissionedStrategy } from "../../../contracts/interfaces/IPermissionedStrategy.sol";
import { MAX_BPS } from "../../../contracts/libraries/Constants.sol";
import { HyperdriveExecutionLibrary } from "../../../contracts/libraries/HyperdriveExecution.sol";
import { EverlongStrategy } from "../../../contracts/EverlongStrategy.sol";
import { EverlongTest } from "../EverlongTest.sol";

/// @dev Test ensuring that Everlong works with sDAI Hyperdrive and
///      AS_BASE=false.
contract TestSDAIVaultSharesToken is EverlongTest {
    using FixedPointMath for *;
    using Lib for *;
    using HyperdriveExecutionLibrary for *;

    /// @dev SDAI whale account used for easy token minting.
    address WHALE = 0x0740c011A4160139Bd2E4EA091581d35ee3454da;

    /// @dev "Mint" tokens to an account by transferring from the whale.
    /// @param _amount Amount of tokens to "mint".
    /// @param _to Destination for the tokens.
    function mintAsset(uint256 _amount, address _to) internal {
        vm.startPrank(WHALE);
        asset.transfer(_to, _amount);
        vm.stopPrank();
    }

    /// @dev Deposit into the SDAI everlong vault.
    /// @param _assets Amount of assets to deposit.
    /// @param _from Source of the tokens.
    /// @return shares Amount of shares received from the deposit.
    function depositSDAI(
        uint256 _assets,
        address _from
    ) internal returns (uint256 shares) {
        mintAsset(_assets, _from);
        vm.startPrank(_from);
        asset.approve(address(vault), _assets);
        shares = vault.deposit(_assets, _from);
        vm.stopPrank();
    }

    /// @dev Redeem shares from the SDAI everlong vault.
    /// @param _shares Amount of shares to redeem.
    /// @param _from Source of the shares.
    /// @return assets Amount of assets received from the redemption.
    function redeemSDAI(
        uint256 _shares,
        address _from
    ) internal returns (uint256 assets) {
        vm.startPrank(_from);
        assets = vault.redeem(_shares, _from, _from);
        vm.stopPrank();
    }

    /// @dev Deploy a strategy pointing to the sDAI hyperdrive instance and
    ///      create a vault around it.
    function setUp() public virtual override {
        super.setUp();

        // sDai Hyperdrive mainnet address.
        hyperdrive = IHyperdrive(0x324395D5d835F84a02A75Aa26814f6fD22F25698);

        // Set the correct asset.
        asset = IERC20(hyperdrive.vaultSharesToken());

        vm.startPrank(deployer);

        // Deploy and configure the strategy.
        strategy = IPermissionedStrategy(
            address(
                new EverlongStrategy(
                    address(asset),
                    "sDAI Strategy",
                    address(hyperdrive),
                    false,
                    false
                )
            )
        );
        strategy.setPerformanceFeeRecipient(governance);
        strategy.setKeeper(address(keeperContract));
        strategy.setPendingManagement(management);
        strategy.setEmergencyAdmin(emergencyAdmin);

        // Issue the deployer a bunch of stETH... this makes it easy to dish
        // out to other users later.
        // uint256 deployerETH = 1_000e18;
        // deal(deployer, deployerETH);
        // ILido(address(asset)).submit{ value: deployerETH }(deployer);

        vm.stopPrank();

        // As the `management` address:
        //   1. Accept the `management` role for the strategy.
        //   2. Set the `profitMaxUnlockTime` to zero.
        vm.startPrank(management);
        strategy.acceptManagement();
        strategy.setProfitMaxUnlockTime(STRATEGY_PROFIT_MAX_UNLOCK_TIME);
        strategy.setPerformanceFee(0);
        vm.stopPrank();

        // As the `governance` address:
        //   1. Deploy the Vault using the RoleManager.
        //   2. Add the EverlongStrategy to the vault.
        //   3. Update the max debt for the strategy to be the maximum uint256.
        //   4. Configure the vault to `auto_allocate` which will automatically
        //      update the strategy's debt on deposit.
        vm.startPrank(governance);
        vault = IVault(
            roleManager.newVault(
                address(asset),
                0,
                EVERLONG_NAME,
                EVERLONG_SYMBOL
            )
        );
        vault.add_strategy(address(strategy));
        vault.update_max_debt_for_strategy(
            address(strategy),
            type(uint256).max
        );
        roleManager.setPositionHolder(
            roleManager.KEEPER(),
            address(keeperContract)
        );
        vm.stopPrank();

        // As the `management` address, configure the DebtAllocator to not
        // wait to update a strategy's debt and set the minimum change before
        // updating to just above hyperdrive's minimum transaction amount.
        vm.startPrank(management);
        // Set the vault's duration for unlocking profit.
        vault.setProfitMaxUnlockTime(VAULT_PROFIT_MAX_UNLOCK_TIME);
        // Enable deposits to the strategy from the vault.
        strategy.setDepositor(address(vault), true);
        // Give the `EverlongStrategyKeeper` role to the keeper address.
        debtAllocator.setKeeper(address(keeperContract), true);
        // Set minimum wait time for updating strategy debt.
        debtAllocator.setMinimumWait(0);
        // Set minimum change in debt for triggering an update.
        debtAllocator.setMinimumChange(
            address(vault),
            MINIMUM_TRANSACTION_AMOUNT + 1
        );
        debtAllocator.setStrategyDebtRatio(
            address(vault),
            address(strategy),
            MAX_BPS - TARGET_IDLE_LIQUIDITY_BASIS_POINTS,
            MAX_BPS - MIN_IDLE_LIQUIDITY_BASIS_POINTS
        );
        vm.stopPrank();
    }

    /// @dev Ensure the deposit functions work as expected.
    function test_deposit() external {
        // Alice and Bob deposit into the vault.
        uint256 depositAmount = 100e18;
        uint256 aliceShares = depositSDAI(depositAmount, alice);
        uint256 bobShares = depositSDAI(depositAmount, bob);

        // Alice and Bob should have non-zero share amounts.
        assertGt(aliceShares, 0);
        assertGt(bobShares, 0);
    }

    /// @dev Ensure the rebalance and redeem functions work as expected.
    function test_redeem() external {
        // Alice and Bob deposit into the vault.
        uint256 depositAmount = 100e18;
        uint256 aliceShares = depositSDAI(depositAmount, alice);
        uint256 bobShares = depositSDAI(depositAmount, bob);

        // The vault allocates funds to the strategy.
        rebalance();

        // Alice and Bob redeem their shares from the vault.
        uint256 aliceRedeemAssets = redeemSDAI(aliceShares, alice);
        uint256 bobRedeemAssets = redeemSDAI(bobShares, bob);

        // Neither Alice nor Bob should have more assets than they began with.
        assertLe(aliceRedeemAssets, depositAmount);
        assertLe(bobRedeemAssets, depositAmount);
    }
}
