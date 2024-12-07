// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { IERC20 } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { CommonReportTrigger } from "lib/vault-periphery/lib/tokenized-strategy-periphery/src/ReportTrigger/CommonReportTrigger.sol";
import { DebtAllocator } from "vault-periphery/debtAllocators/DebtAllocator.sol";
import { IVault } from "yearn-vaults-v3/interfaces/IVault.sol";
import { IAccountant } from "../../contracts/interfaces/IAccountant.sol";
import { IAprOracle } from "../../contracts/interfaces/IAprOracle.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { IEverlongStrategyFactory } from "../../contracts/interfaces/IEverlongStrategyFactory.sol";
import { IRoleManager } from "../../contracts/interfaces/IRoleManager.sol";
import { IRoleManagerFactory } from "../../contracts/interfaces/IRoleManagerFactory.sol";
import { MAX_BPS } from "../../contracts/libraries/Constants.sol";
import { EverlongStrategyFactory } from "../../contracts/EverlongStrategyFactory.sol";
import { EverlongStrategyKeeper } from "../../contracts/EverlongStrategyKeeper.sol";

/// @dev Everlong testing harness contract.
/// @dev Tests should extend this contract and call its `setUp` function.
contract EverlongTest is HyperdriveTest, IEverlongEvents {
    using HyperdriveUtils for *;
    using FixedPointMath for *;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                        HyperdriveTest Storage                         │
    // ╰───────────────────────────────────────────────────────────────────────╯

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

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                       Hyperdrive Configuration                        │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Address calling `initialize(..)` on the hyperdrive instance.
    address internal HYPERDRIVE_INITIALIZER = address(0);

    /// @dev Fixed rate for the hyperdrive instance.
    uint256 internal FIXED_RATE = 0.05e18;

    /// @dev Variable rate for the hyperdrive instance.
    int256 internal VARIABLE_RATE = 0.05e18;

    /// @dev Initial vault share price for the hyperdrive instance.
    uint256 internal INITIAL_VAULT_SHARE_PRICE = 1e18;

    /// @dev Initial contribution for the hyperdrive instance.
    uint256 internal INITIAL_CONTRIBUTION = 1_000_000e18;

    /// @dev Curve fee for the hyperdrive instance.
    uint256 internal CURVE_FEE = 0.01e18;

    /// @dev Flat fee for the hyperdrive instance.
    uint256 internal FLAT_FEE = 0.0005e18;

    /// @dev Governance LP fee for the hyperdrive instance.
    uint256 internal GOVERNANCE_LP_FEE = 0.15e18;

    /// @dev Governance Zombie fee for the hyperdrive instance.
    uint256 internal GOVERNANCE_ZOMBIE_FEE = 0.03e18;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                           Everlong Storage                            │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Time period for the strategy to release profits over.
    uint256 internal STRATEGY_PROFIT_MAX_UNLOCK_TIME = 0 days;

    /// @dev Time period for the strategy to release profits over.
    uint256 internal VAULT_PROFIT_MAX_UNLOCK_TIME = 1 days;

    /// @dev Everlong asset.
    IERC20 internal asset;

    /// @dev Everlong token name.
    string internal EVERLONG_NAME = "Everlong Testing";

    /// @dev Everlong token symbol.
    string internal EVERLONG_SYMBOL = "EVRLNG";

    /// @dev Minimum idle liquidity (in basis points) for the Everlong vault.
    uint256 internal MIN_IDLE_LIQUIDITY_BASIS_POINTS = 500;

    /// @dev Target idle liquidity (in basis points) for the Everlong vault.
    uint256 internal TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 1000;

    /// @dev Maximum slippage for bond purchases.
    uint256 internal MIN_OUTPUT_SLIPPAGE = 500;

    /// @dev Maximum slippage for vault share price.
    uint256 internal MIN_VAULT_SHARE_PRICE_SLIPPAGE = 500;

    /// @dev Everlong vault management address.
    /// @dev Used when interacting with the `DebtAllocator`.
    address internal management;

    /// @dev Everlong keeper address.
    address internal keeper;

    /// @dev Mainnet `RoleManager` factory.
    IRoleManagerFactory internal roleManagerFactory =
        IRoleManagerFactory(0xca12459a931643BF28388c67639b3F352fe9e5Ce);

    /// @dev Everlong strategy factory.
    IEverlongStrategyFactory internal strategyFactory;

    /// @dev Everlong strategy.
    IEverlongStrategy internal strategy;

    /// @dev Everlong vault.
    IVault internal vault;

    /// @dev Everlong vault role manager.
    /// @dev Handles setup and permissioning for
    ///      vault periphery contracts such as DebtAllocator and Accountant.
    IRoleManager internal roleManager;

    /// @dev Everlong vault debt allocator.
    /// @dev Handles vault debt allocation to strategies.
    DebtAllocator internal debtAllocator;

    /// @dev Everlong vault accountant.
    /// @dev Handles fee and reporting configuration.
    IAccountant internal accountant;

    /// @dev Yearn apr oracle.
    /// @dev Capable of getting the current and expected apr for any vault or
    ///      strategy.
    IAprOracle internal aprOracle =
        IAprOracle(0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92);

    /// @dev Shared contract providing default triggers for vault reporting,
    ///      strategy reporting, and strategy tending.
    CommonReportTrigger internal reportTrigger =
        CommonReportTrigger(0xA045D4dAeA28BA7Bfe234c96eAa03daFae85A147);

    /// @dev Periphery contract to simplify maintenance operations for vaults
    ///      and strategies.
    EverlongStrategyKeeper internal keeperContract;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                             SetUp Helpers                             │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Set up the testing environment on a fork of mainnet.
    function setUp() public virtual override {
        vm.createSelectFork(vm.rpcUrl("mainnet"));
        super.setUp();
        setUpHyperdrive();
        setUpRoleManager();
        setUpEverlongStrategy();
        setUpEverlongVault();
    }

    /// @dev Deploy and initialize the hyperdrive instance with seed liquidity.
    function setUpHyperdrive() internal {
        vm.startPrank(deployer);

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
        asset = IERC20(hyperdrive.baseToken());

        // Seed liquidity for the hyperdrive instance.
        if (HYPERDRIVE_INITIALIZER == address(0)) {
            HYPERDRIVE_INITIALIZER = deployer;
        }
        initialize(HYPERDRIVE_INITIALIZER, FIXED_RATE, INITIAL_CONTRIBUTION);
        advanceTimeWithCheckpoints(1);

        vm.stopPrank();
    }

    /// @dev Deploy the RoleManager and store the periphery contract addresses.
    function setUpRoleManager() internal {
        // Set up the `management` address.
        (management, ) = createUser("management");

        // Deploy the RoleManager from the factory and store the relevant
        // RoleManager component addresses.
        vm.startPrank(deployer);
        roleManager = IRoleManager(
            roleManagerFactory.newProject("Everlong", governance, management)
        );
        debtAllocator = DebtAllocator(roleManager.getDebtAllocator());
        accountant = IAccountant(roleManager.getAccountant());
        vm.stopPrank();
    }

    /// @dev Deploy the Everlong Yearn Tokenized Strategy.
    function setUpEverlongStrategy() internal {
        vm.startPrank(deployer);
        // Set Up the `keeper` address.
        (keeper, ) = createUser("keeper");

        // Deploy the EverlongStrategyKeeper helper contract.
        keeperContract = new EverlongStrategyKeeper(
            address(roleManager),
            address(reportTrigger)
        );
        keeperContract.transferOwnership(keeper);

        // Deploy the EverlongStrategyFactory.
        strategyFactory = new EverlongStrategyFactory(
            "TestEverlongStrategyFactory", // Name
            management, // Management
            governance, // Performance Fee Recipient
            address(keeperContract), // EverlongStrategyKeeper
            deployer // Emergency Admin
        );

        // Deploy the Strategy.
        strategy = IEverlongStrategy(
            address(
                strategyFactory.newStrategy(
                    address(asset),
                    EVERLONG_NAME,
                    address(hyperdrive),
                    true
                )
            )
        );
        vm.stopPrank();

        // As the `management` address:
        //   1. Accept the `management` role for the strategy.
        //   2. Set the `profitMaxUnlockTime` to zero.
        vm.startPrank(management);
        strategy.acceptManagement();
        strategy.setProfitMaxUnlockTime(STRATEGY_PROFIT_MAX_UNLOCK_TIME);
        strategy.setPerformanceFee(0);
        vm.stopPrank();
    }

    /// @dev Deploy the Everlong Yearn v3 Vault.
    function setUpEverlongVault() internal {
        // As the `governance` address:
        //   1. Accept the "Fee Manager" role for the Accountant.
        //   2. Set the default `config.maxLoss` for the accountant to be 10%.
        //      This will enable losses of up to 10% across reports before
        //      reverting.
        //   3. Deploy the Vault using the RoleManager.
        //   4. Add the EverlongStrategy to the vault.
        //   5. Update the max debt for the strategy to be the maximum uint256.
        //   6. Configure the vault to `auto_allocate` which will automatically
        //      update the strategy's debt on deposit.
        vm.startPrank(governance);
        accountant.acceptFeeManager();
        IAccountant.Fee memory defaultConfig = accountant.defaultConfig();
        // Must increase the accountant maxLoss for reporting since `totalAssets`
        // decreases whenever opening longs.
        accountant.updateDefaultConfig(0, 0, 0, 0, defaultConfig.maxGain, 100);
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
        // TODO: Ensure this is what we want. Pendle has their strategy
        //       `profitMaxUnlockTime` set to 0 and their vault's set to
        //       3 days.
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

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                            Deposit Helpers                            │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Deposit into Everlong strategy.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @return shares Amount of shares received from the deposit.
    function depositStrategy(
        uint256 _amount,
        address _depositor
    ) internal returns (uint256 shares) {
        return depositStrategy(_amount, _depositor, false);
    }

    // NOTE: Core functionality for all `depositStrategy(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function depositStrategy(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance
    ) internal returns (uint256 shares) {
        // Resolve the appropriate token.
        ERC20Mintable token = ERC20Mintable(vault.asset());

        // Enable deposits from _depositor.
        vm.startPrank(management);
        strategy.setDepositor(_depositor, true);
        vm.stopPrank();

        // Mint sufficient tokens to _depositor.
        vm.startPrank(_depositor);
        token.mint(_amount);
        vm.stopPrank();

        // Approve everlong as _depositor.
        vm.startPrank(_depositor);
        token.approve(address(strategy), _amount);
        vm.stopPrank();

        // Make the deposit.
        vm.startPrank(_depositor);
        shares = strategy.deposit(_amount, _depositor);
        vm.stopPrank();

        // Rebalance if specified.
        if (_shouldRebalance) {
            rebalance();
        }

        // Return the amount of shares issued to _depositor for the deposit.
        return shares;
    }

    /// @dev Deposit into Everlong vault.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @return shares Amount of shares received from the deposit.
    function depositVault(
        uint256 _amount,
        address _depositor
    ) internal returns (uint256 shares) {
        return depositVault(_amount, _depositor, false);
    }

    // NOTE: Core functionality for all `depositVault(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function depositVault(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance
    ) internal returns (uint256 shares) {
        // Resolve the appropriate token.
        ERC20Mintable token = ERC20Mintable(vault.asset());

        // Mint sufficient tokens to _depositor.
        vm.startPrank(_depositor);
        token.mint(_amount);
        vm.stopPrank();

        // Approve everlong as _depositor.
        vm.startPrank(_depositor);
        token.approve(address(vault), _amount);
        vm.stopPrank();

        // Make the deposit.
        vm.startPrank(_depositor);
        shares = vault.deposit(_amount, _depositor);
        vm.stopPrank();

        // Rebalance if specified.
        if (_shouldRebalance) {
            rebalance();
        }

        // Return the amount of shares issued to _depositor for the deposit.
        return shares;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                            Redeem Helpers                             │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Redeem shares from Everlong strategy.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @return assets Amount of assets received from the redemption.
    function redeemStrategy(
        uint256 _shares,
        address _redeemer
    ) internal returns (uint256 assets) {
        assets = redeemStrategy(_shares, _redeemer, false);
        return assets;
    }

    // NOTE: Core functionality for all `redeemStrategy(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function redeemStrategy(
        uint256 _amount,
        address _redeemer,
        bool _shouldRebalance
    ) internal returns (uint256 proceeds) {
        // Make the redemption.
        vm.startPrank(_redeemer);
        proceeds = strategy.redeem(_amount, _redeemer, _redeemer);
        vm.stopPrank();

        // Rebalance if specified.
        if (_shouldRebalance) {
            rebalance();
        }
    }

    /// @dev Redeem shares from Everlong vault.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @return assets Amount of assets received from the redemption.
    function redeemVault(
        uint256 _shares,
        address _redeemer
    ) internal returns (uint256 assets) {
        assets = redeemVault(_shares, _redeemer, false);
        return assets;
    }

    // NOTE: Core functionality for all `redeemVault(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function redeemVault(
        uint256 _amount,
        address _redeemer,
        bool _shouldRebalance
    ) internal returns (uint256 proceeds) {
        // Make the redemption.
        vm.startPrank(_redeemer);
        proceeds = vault.redeem(_amount, _redeemer, _redeemer);
        vm.stopPrank();

        // Rebalance if specified.
        if (_shouldRebalance) {
            rebalance();
        }
    }

    /// @dev Mint base token to the provided address and approve Everlong.
    /// @param _recipient Receiver of the minted assets.
    /// @param _amount Amount of assets to mint.
    function mintApproveEverlongBaseAsset(
        address _recipient,
        uint256 _amount
    ) internal {
        ERC20Mintable(address(asset)).mint(_recipient, _amount);
        vm.startPrank(_recipient);
        ERC20Mintable(address(asset)).approve(address(vault), _amount);
        vm.stopPrank();
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                          Rebalancing Helpers                          │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Call `everlong.rebalance(...)` as the admin with default options.
    function rebalance() internal {
        vm.startPrank(keeper);
        keeperContract.update_debt(address(vault), address(strategy));
        keeperContract.tend(
            address(strategy),
            IEverlongStrategy.TendConfig({
                minOutput: keeperContract.calculateMinOutput(
                    address(strategy),
                    MIN_OUTPUT_SLIPPAGE
                ),
                minVaultSharePrice: keeperContract.calculateMinVaultSharePrice(
                    address(strategy),
                    MIN_VAULT_SHARE_PRICE_SLIPPAGE
                ),
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        vm.stopPrank();
        // Skip forward one second so that `update_debt` doesn't get called on
        // the same timestamp.
        skip(1);
    }

    /// @dev Call `report` on the strategy then call `process_report` on the
    ///      vault if needed.
    function report() internal {
        vm.startPrank(keeper);
        keeperContract.strategyReport(
            address(strategy),
            IEverlongStrategy.TendConfig({
                minOutput: keeperContract.calculateMinOutput(
                    address(strategy),
                    MIN_OUTPUT_SLIPPAGE
                ),
                minVaultSharePrice: keeperContract.calculateMinVaultSharePrice(
                    address(strategy),
                    MIN_VAULT_SHARE_PRICE_SLIPPAGE
                ),
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        keeperContract.processReport(address(vault), address(strategy));
        vm.stopPrank();
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                             Time Helpers                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Advance time by the specified amount at the global variable rate.
    /// @param _time Amount of time to advance.
    function advanceTimeWithCheckpoints(uint256 _time) internal virtual {
        advanceTimeWithCheckpoints(_time, VARIABLE_RATE);
    }

    /// @dev Advance time and rebalance on the specified interval.
    /// @dev If time % _rebalanceInterval != 0 then it ends up advancing time
    ///      to the next _rebalanceInterval.
    /// @param _time Amount of time to advance.
    /// @param _rebalanceInterval Amount of time between rebalances.
    function advanceTimeWithRebalancing(
        uint256 _time,
        uint256 _rebalanceInterval
    ) internal virtual {
        uint256 startTimeElapsed = block.timestamp;
        // Note: if time % _rebalanceInterval != 0 then it ends up
        // advancing time to the next _rebalanceInterval.
        while (block.timestamp - startTimeElapsed < _time) {
            advanceTime(_rebalanceInterval, VARIABLE_RATE);
            rebalance();
        }
    }

    /// @dev Advance time, create checkpoints, and report at checkpoints.
    /// @dev If time % _rebalanceInterval != 0 then it ends up advancing time
    ///      to the next _rebalanceInterval.
    /// @param _time Amount of time to advance.
    function advanceTimeWithCheckpointsAndReporting(
        uint256 _time
    ) internal virtual {
        uint256 startTimeElapsed = block.timestamp;
        // Note: if time % CHECKPOINT_DURATION != 0 then it ends up
        // advancing time to the next checkpoint.
        while (block.timestamp - startTimeElapsed < _time) {
            advanceTime(CHECKPOINT_DURATION, VARIABLE_RATE);
            // Create the checkpoint.
            hyperdrive.checkpoint(
                HyperdriveUtils.latestCheckpoint(hyperdrive),
                0
            );
            // Update debt for the vault and rebalance the strategy.
            rebalance();
            // Generate reports for the strategy and vault.
            report();
        }
    }

    /// @dev Advance time, create checkpoints, and rebalance at checkpoints.
    /// @dev If time % _rebalanceInterval != 0 then it ends up advancing time
    ///      to the next _rebalanceInterval.
    /// @param _time Amount of time to advance.
    function advanceTimeWithCheckpointsAndRebalancing(
        uint256 _time
    ) internal virtual {
        uint256 startTimeElapsed = block.timestamp;
        // Note: if time % CHECKPOINT_DURATION != 0 then it ends up
        // advancing time to the next checkpoint.
        while (block.timestamp - startTimeElapsed < _time) {
            advanceTime(CHECKPOINT_DURATION, VARIABLE_RATE);
            // Create the checkpoint.
            hyperdrive.checkpoint(
                HyperdriveUtils.latestCheckpoint(hyperdrive),
                0
            );
            // Update debt for the vault and rebalance the strategy.
            rebalance();
        }
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                        Idle Liquidity Helpers                         │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Calculates the target amount of idle assets for the vault.
    /// @return Target idle assets for the vault.
    function targetIdleLiquidity() internal virtual returns (uint256) {
        return
            (MAX_BPS -
                uint256(
                    debtAllocator
                        .getStrategyConfig(address(vault), address(strategy))
                        .targetRatio
                )).mulDivDown(vault.totalAssets(), MAX_BPS);
    }

    /// @dev Calculates the minimum amount of idle assets for the vault.
    /// @return Minimum idle assets for the vault.
    function minIdleLiquidity() internal virtual returns (uint256) {
        return
            (MAX_BPS -
                uint256(
                    debtAllocator
                        .getStrategyConfig(address(vault), address(strategy))
                        .maxRatio
                )).mulDivDown(vault.totalAssets(), MAX_BPS);
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                           Position Helpers                            │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Outputs a table of all positions.
    function logPositions() internal view {
        /* solhint-disable no-console */
        console.log("-- POSITIONS -------------------------------");
        for (uint128 i = 0; i < strategy.positionCount(); ++i) {
            IEverlongStrategy.Position memory p = strategy.positionAt(i);
            console.log(
                "index: %e - maturityTime: %e - bondAmount: %e",
                i,
                p.maturityTime,
                p.bondAmount
            );
        }
        console.log("--------------------------------------------");
        /* solhint-enable no-console */
    }
}
