// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";
import { Roles } from "yearn-vaults-v3/interfaces/Roles.sol";
import { IVaultFactory } from "yearn-vaults-v3/interfaces/IVaultFactory.sol";
import { DebtAllocator } from "vault-periphery/debtAllocators/DebtAllocator.sol";
import { Positions } from "vault-periphery/managers/Positions.sol";
import { Registry } from "vault-periphery/registry/Registry.sol";
import { ReleaseRegistry } from "vault-periphery/registry/ReleaseRegistry.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";
import { IAprOracle } from "../../contracts/interfaces/IAprOracle.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { IEverlongStrategyFactory } from "../../contracts/interfaces/IEverlongStrategyFactory.sol";
import { EverlongStrategyFactory } from "../../contracts/EverlongStrategyFactory.sol";
import { EverlongStrategy } from "../../contracts/EverlongStrategy.sol";
import { IRoleManagerFactory } from "../../contracts/interfaces/IRoleManagerFactory.sol";
import { IRoleManager } from "../../contracts/interfaces/IRoleManager.sol";
import { IVault } from "yearn-vaults-v3/interfaces/IVault.sol";
import { IAccountant } from "../../contracts/interfaces/IAccountant.sol";

// TODO: Refactor this to include an instance of `Everlong` with exposed internal functions.
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

    address internal HYPERDRIVE_INITIALIZER = address(0);

    uint256 internal FIXED_RATE = 0.05e18;
    int256 internal VARIABLE_RATE = 0.025e18;

    uint256 internal INITIAL_VAULT_SHARE_PRICE = 1e18;
    uint256 internal INITIAL_CONTRIBUTION = 2_000_000e18;

    uint256 internal CURVE_FEE = 0.01e18;
    uint256 internal FLAT_FEE = 0.0005e18;
    uint256 internal GOVERNANCE_LP_FEE = 0.15e18;
    uint256 internal GOVERNANCE_ZOMBIE_FEE = 0.03e18;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                           Everlong Storage                            │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Everlong token name.
    string internal EVERLONG_NAME = "Everlong Testing";

    /// @dev Everlong token symbol.
    string internal EVERLONG_SYMBOL = "EVRLNG";

    uint256 internal TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 0;
    uint256 internal MIN_IDLE_LIQUIDITY_BASIS_POINTS = 0;

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

    IEverlongStrategy.RebalanceOptions internal DEFAULT_REBALANCE_OPTIONS =
        IEverlongStrategy.RebalanceOptions({
            spendingLimit: 0,
            minOutput: 0,
            minVaultSharePrice: 0,
            positionClosureLimit: 0,
            extraData: ""
        });

    IRoleManager internal roleManager;
    DebtAllocator internal debtAllocator;
    Registry internal yearnRegistry;
    IAccountant internal accountant;
    IAprOracle internal aprOracle =
        IAprOracle(0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92);

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                             SetUp Helpers                             │
    // ╰───────────────────────────────────────────────────────────────────────╯

    function setUp() public virtual override {
        vm.createSelectFork(vm.rpcUrl("mainnet"));
        super.setUp();
        setUpHyperdrive();
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

        // Seed liquidity for the hyperdrive instance.
        if (HYPERDRIVE_INITIALIZER == address(0)) {
            HYPERDRIVE_INITIALIZER = deployer;
        }
        initialize(HYPERDRIVE_INITIALIZER, FIXED_RATE, INITIAL_CONTRIBUTION);

        vm.stopPrank();
    }

    /// @dev Deploy the Everlong Yearn Tokenized Strategy.
    function setUpEverlongStrategy() internal {
        vm.startPrank(deployer);

        // Set up the `management` address.
        management = createUser("management");

        // Set Up the `keeper` address.
        keeper = createUser("keeper");

        // Deploy the EverlongStrategyFactory.
        strategyFactory = new EverlongStrategyFactory(
            management, // Management
            governance, // Performance Fee Recipient
            keeper, // Keeper
            deployer // Emergency Admin
        );

        // Deploy the Strategy.
        strategy = IEverlongStrategy(
            address(
                strategyFactory.newStrategy(
                    address(hyperdrive.baseToken()),
                    EVERLONG_NAME,
                    address(hyperdrive),
                    true
                )
            )
        );

        vm.stopPrank();

        // Set the `profitMaxUnlockTime` to 0.
        vm.startPrank(management);
        strategy.acceptManagement();
        strategy.setProfitMaxUnlockTime(0);
        vm.stopPrank();
    }

    /// @dev Deploy the Everlong Yearn v3 Vault.
    function setUpEverlongVault() internal {
        // Deploy the RoleManager from the factory and store the relevant
        // RoleManager component addresses.
        vm.startPrank(deployer);
        roleManager = IRoleManager(
            roleManagerFactory.newProject("Everlong", governance, management)
        );
        debtAllocator = DebtAllocator(roleManager.getDebtAllocator());
        yearnRegistry = Registry(roleManager.getRegistry());
        accountant = IAccountant(roleManager.getAccountant());
        vm.stopPrank();

        console.log("Fee Manager: %s", accountant.feeManager());

        // As the `governance` address:
        //   1. Deploy the Vault using the RoleManager.
        //   2. Add the EverlongStrategy to the vault.
        //   3. Update the max debt for the strategy to be the maximum uint256.
        vm.startPrank(governance);
        vault = IVault(
            roleManager.newVault(
                address(hyperdrive.baseToken()),
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
        vm.stopPrank();

        // vm.prank(address(roleManagerFactory));
        // accountant.turnOffHealthCheck(address(vault), address(strategy));

        // As the `management` address, configure the DebtAllocator to not
        // wait to update a strategy's debt and set the minimum change before
        // updating at 1 BP.
        vm.startPrank(management);
        vault.setProfitMaxUnlockTime(1 days);
        debtAllocator.setMinimumWait(6 hours);
        debtAllocator.setMinimumChange(
            address(vault),
            MINIMUM_TRANSACTION_AMOUNT
        );
        debtAllocator.setStrategyDebtRatio(
            address(vault),
            address(strategy),
            10_000 - TARGET_IDLE_LIQUIDITY_BASIS_POINTS,
            10_000 - MIN_IDLE_LIQUIDITY_BASIS_POINTS
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
        return
            depositStrategy(
                _amount,
                _depositor,
                false,
                IEverlongStrategy.RebalanceOptions({
                    spendingLimit: 0,
                    minOutput: 0,
                    minVaultSharePrice: 0,
                    positionClosureLimit: 0,
                    extraData: ""
                })
            );
    }

    /// @dev Deposit into Everlong strategy.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @param _shouldRebalance Whether to rebalance after the deposit is made.
    /// @return shares Amount of shares received from the deposit.
    function depositStrategy(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance
    ) internal returns (uint256 shares) {
        return
            depositStrategy(
                _amount,
                _depositor,
                _shouldRebalance,
                IEverlongStrategy.RebalanceOptions({
                    spendingLimit: 0,
                    minOutput: 0,
                    minVaultSharePrice: 0,
                    positionClosureLimit: 0,
                    extraData: ""
                })
            );
    }

    /// @dev Deposit into Everlong strategy and call tend after the deposit.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @param _rebalanceOptions Options to pass to the rebalance call.
    /// @return shares Amount of shares received from the deposit.
    function depositStrategy(
        uint256 _amount,
        address _depositor,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
    ) internal returns (uint256 shares) {
        return depositStrategy(_amount, _depositor, true, _rebalanceOptions);
    }

    // NOTE: Core functionality for all `depositStrategy(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function depositStrategy(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
    ) private returns (uint256 shares) {
        // Resolve the appropriate token.
        ERC20Mintable token = ERC20Mintable(vault.asset());

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
        return
            depositVault(
                _amount,
                _depositor,
                false,
                IEverlongStrategy.RebalanceOptions({
                    spendingLimit: 0,
                    minOutput: 0,
                    minVaultSharePrice: 0,
                    positionClosureLimit: 0,
                    extraData: ""
                })
            );
    }

    /// @dev Deposit into Everlong vault.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @param _shouldRebalance Whether to rebalance after the deposit is made.
    /// @return shares Amount of shares received from the deposit.
    function depositVault(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance
    ) internal returns (uint256 shares) {
        return
            depositVault(
                _amount,
                _depositor,
                _shouldRebalance,
                IEverlongStrategy.RebalanceOptions({
                    spendingLimit: 0,
                    minOutput: 0,
                    minVaultSharePrice: 0,
                    positionClosureLimit: 0,
                    extraData: ""
                })
            );
    }

    /// @dev Deposit into Everlong vault and call tend after the deposit.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @param _rebalanceOptions Options to pass to the rebalance call.
    /// @return shares Amount of shares received from the deposit.
    function depositVault(
        uint256 _amount,
        address _depositor,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
    ) internal returns (uint256 shares) {
        return depositVault(_amount, _depositor, true, _rebalanceOptions);
    }

    // NOTE: Core functionality for all `depositVault(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function depositVault(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
    ) private returns (uint256 shares) {
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
        assets = redeemStrategy(
            _shares,
            _redeemer,
            true,
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        return assets;
    }

    /// @dev Redeem shares from Everlong strategy.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @param _shouldRebalance Whether to rebalance after the redeem is made.
    /// @return assets Amount of assets received from the redemption.
    function redeemStrategy(
        uint256 _shares,
        address _redeemer,
        bool _shouldRebalance
    ) internal returns (uint256 assets) {
        assets = redeemStrategy(
            _shares,
            _redeemer,
            _shouldRebalance,
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        return assets;
    }

    /// @dev Redeem shares from Everlong strategy.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @param _rebalanceOptions Options to pass to the rebalance call.
    /// @return assets Amount of assets received from the redemption.
    function redeemStrategy(
        uint256 _shares,
        address _redeemer,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
    ) internal returns (uint256 assets) {
        assets = redeemStrategy(_shares, _redeemer, true, _rebalanceOptions);
        return assets;
    }

    // NOTE: Core functionality for all `redeemStrategy(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function redeemStrategy(
        uint256 _amount,
        address _redeemer,
        bool _shouldRebalance,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
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
        assets = redeemVault(
            _shares,
            _redeemer,
            true,
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        return assets;
    }

    /// @dev Redeem shares from Everlong vault.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @param _shouldRebalance Whether to rebalance after the redeem is made.
    /// @return assets Amount of assets received from the redemption.
    function redeemVault(
        uint256 _shares,
        address _redeemer,
        bool _shouldRebalance
    ) internal returns (uint256 assets) {
        assets = redeemVault(
            _shares,
            _redeemer,
            _shouldRebalance,
            IEverlongStrategy.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        return assets;
    }

    /// @dev Redeem shares from Everlong vault.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @param _rebalanceOptions Options to pass to the rebalance call.
    /// @return assets Amount of assets received from the redemption.
    function redeemVault(
        uint256 _shares,
        address _redeemer,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
    ) internal returns (uint256 assets) {
        assets = redeemVault(_shares, _redeemer, true, _rebalanceOptions);
        return assets;
    }

    // NOTE: Core functionality for all `redeemVault(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function redeemVault(
        uint256 _amount,
        address _redeemer,
        bool _shouldRebalance,
        IEverlongStrategy.RebalanceOptions memory _rebalanceOptions
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
        ERC20Mintable(hyperdrive.baseToken()).mint(_recipient, _amount);
        vm.startPrank(_recipient);
        ERC20Mintable(hyperdrive.baseToken()).approve(address(vault), _amount);
        vm.stopPrank();
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                          Rebalancing Helpers                          │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Call `everlong.rebalance(...)` as the admin with default options.
    function rebalance() internal {
        vm.prank(management);
        debtAllocator.update_debt(
            address(vault),
            address(strategy),
            type(uint256).max
        );
        vm.prank(keeper);
        strategy.tend();
    }

    function report() internal {
        vm.prank(keeper);
        strategy.report();
        vm.prank(management);
        vault.process_report(address(strategy));
    }

    function rebalance(
        IEverlongStrategy.RebalanceOptions memory _options
    ) internal virtual {
        rebalance();
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

    /// @dev Advance time and rebalance on the specified interval.
    /// @dev If time % _rebalanceInterval != 0 then it ends up advancing time
    ///      to the next _rebalanceInterval.
    /// @param _time Amount of time to advance.
    /// @param _rebalanceInterval Amount of time between rebalances.
    /// @param _options Rebalance options to pass to Everlong.
    function advanceTimeWithRebalancing(
        uint256 _time,
        uint256 _rebalanceInterval,
        IEverlongStrategy.RebalanceOptions memory _options
    ) internal virtual {
        uint256 startTimeElapsed = block.timestamp;
        // Note: if time % _rebalanceInterval != 0 then it ends up
        // advancing time to the next _rebalanceInterval.
        while (block.timestamp - startTimeElapsed < _time) {
            advanceTime(_rebalanceInterval, VARIABLE_RATE);
            rebalance(_options);
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
            hyperdrive.checkpoint(
                HyperdriveUtils.latestCheckpoint(hyperdrive),
                0
            );
            rebalance();
        }
    }

    /// @dev Advance time, create checkpoints, and rebalance at checkpoints.
    /// @dev If time % _rebalanceInterval != 0 then it ends up advancing time
    ///      to the next _rebalanceInterval.
    /// @param _time Amount of time to advance.
    /// @param _options Rebalance options to pass to Everlong.
    function advanceTimeWithCheckpointsAndRebalancing(
        uint256 _time,
        IEverlongStrategy.RebalanceOptions memory _options
    ) internal virtual {
        uint256 startTimeElapsed = block.timestamp;
        // Note: if time % CHECKPOINT_DURATION != 0 then it ends up
        // advancing time to the next checkpoint.
        while (block.timestamp - startTimeElapsed < _time) {
            advanceTime(CHECKPOINT_DURATION, VARIABLE_RATE);
            hyperdrive.checkpoint(
                HyperdriveUtils.latestCheckpoint(hyperdrive),
                0
            );
            rebalance(_options);
        }
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                        Idle Liquidity Helpers                         │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Calculates the target amount of idle assets for the vault.
    /// @return Target idle assets for the vault.
    function targetIdleLiquidity() internal virtual returns (uint256) {
        return
            (10_000 -
                uint256(
                    debtAllocator
                        .getStrategyConfig(address(vault), address(strategy))
                        .targetRatio
                )).mulDivDown(vault.totalAssets(), 10_000);
    }

    /// @dev Calculates the minimum amount of idle assets for the vault.
    /// @return Minimum idle assets for the vault.
    function minIdleLiquidity() internal virtual returns (uint256) {
        return
            (10_000 -
                uint256(
                    debtAllocator
                        .getStrategyConfig(address(vault), address(strategy))
                        .maxRatio
                )).mulDivDown(vault.totalAssets(), 10_000);
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
