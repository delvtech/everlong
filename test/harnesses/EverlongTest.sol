// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { HyperdriveTest } from "hyperdrive/test/utils/HyperdriveTest.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IEverlongEvents } from "../../contracts/interfaces/IEverlongEvents.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { EverlongExposed } from "../exposed/EverlongExposed.sol";
import { Strategy, ERC20 } from "../../contracts/Strategy.sol";
import { StrategyFactory } from "../../contracts/StrategyFactory.sol";
import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";
import { TokenizedStrategy } from "./TokenizedStrategy.sol";
import { IRoleManagerFactory } from "../../contracts/interfaces/IRoleManagerFactory.sol";
import { IRoleManager } from "../../contracts/interfaces/IRoleManager.sol";
import { IVault } from "yearn-vaults-v3/interfaces/IVault.sol";
import { Roles } from "yearn-vaults-v3/interfaces/Roles.sol";
import { IVaultFactory } from "yearn-vaults-v3/interfaces/IVaultFactory.sol";
import { DebtAllocator } from "vault-periphery/debtAllocators/DebtAllocator.sol";
import { Registry } from "vault-periphery/registry/Registry.sol";
import { ReleaseRegistry } from "vault-periphery/registry/ReleaseRegistry.sol";

// TODO: Refactor this to include an instance of `Everlong` with exposed internal functions.
/// @dev Everlong testing harness contract.
/// @dev Tests should extend this contract and call its `setUp` function.
contract EverlongTest is HyperdriveTest, IEverlongEvents {
    using HyperdriveUtils for *;
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

    StrategyFactory internal strategyFactory;

    /// @dev Everlong instance to test.
    EverlongExposed internal everlong;

    /// @dev Everlong token name.
    string internal EVERLONG_NAME = "Everlong Testing";

    /// @dev Everlong token symbol.
    string internal EVERLONG_SYMBOL = "evTest";

    uint256 internal TARGET_IDLE_LIQUIDITY_PERCENTAGE = 0.1e18;
    uint256 internal MAX_IDLE_LIQUIDITY_PERCENTAGE = 0.2e18;

    IEverlong.RebalanceOptions internal DEFAULT_REBALANCE_OPTIONS =
        IEverlong.RebalanceOptions({
            spendingLimit: 0,
            minOutput: 0,
            minVaultSharePrice: 0,
            positionClosureLimit: 0,
            extraData: ""
        });

    // ── YEARN ──────────────────────────────────────────────────

    IRoleManagerFactory internal roleManagerFactory =
        IRoleManagerFactory(0xca12459a931643BF28388c67639b3F352fe9e5Ce);
    IVaultFactory internal vaultFactory =
        IVaultFactory(0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F); // v3.0.4 vault factory
    // IVaultFactory internal vaultFactory =
    //     IVaultFactory(0x444045c5C13C246e117eD36437303cac8E250aB0); // v3.0.2 vault factory
    IRoleManager internal roleManager;
    DebtAllocator internal debtAllocator;
    Registry internal yearnRegistry;
    IVault internal vault;
    IEverlongStrategy internal strategy;

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

    function setUp() public virtual override {
        vm.createSelectFork(vm.rpcUrl("mainnet"));
        super.setUp();
    }

    ///// @dev Deploy the Everlong instance with default underlying, name,
    /////      and symbol.
    //function deployEverlong() internal {
    //    // Deploy the hyperdrive instance.
    //    deploy(
    //        deployer,
    //        FIXED_RATE,
    //        INITIAL_VAULT_SHARE_PRICE,
    //        CURVE_FEE,
    //        FLAT_FEE,
    //        GOVERNANCE_LP_FEE,
    //        GOVERNANCE_ZOMBIE_FEE
    //    );
    //
    //    // Seed liquidity for the hyperdrive instance.
    //    if (HYPERDRIVE_INITIALIZER == address(0)) {
    //        HYPERDRIVE_INITIALIZER = deployer;
    //    }
    //    initialize(HYPERDRIVE_INITIALIZER, FIXED_RATE, INITIAL_CONTRIBUTION);
    //
    //    vm.startPrank(deployer);
    //    everlong = new EverlongExposed(
    //        EVERLONG_NAME,
    //        EVERLONG_SYMBOL,
    //        hyperdrive.decimals(),
    //        address(hyperdrive),
    //        true,
    //        TARGET_IDLE_LIQUIDITY_PERCENTAGE,
    //        MAX_IDLE_LIQUIDITY_PERCENTAGE
    //    );
    //    vm.stopPrank();
    //
    //    // Fast forward and accrue some interest.
    //    advanceTimeWithCheckpoints(POSITION_DURATION * 2);
    //}
    //

    /// @dev Deploy the yearn vault RoleManager and store the addresses of all
    ///      the components.
    function deployRoleManager() internal {
        roleManager = IRoleManager(
            roleManagerFactory.newProject("Everlong", deployer, deployer)
        );
        debtAllocator = DebtAllocator(roleManager.getDebtAllocator());
        yearnRegistry = Registry(roleManager.getRegistry());
    }

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

        // Deploy Everlong
        vm.startPrank(deployer);

        // Deploy the RoleManager from the RoleManagerFactory.
        deployRoleManager();
        vault = IVault(
            // Deploy the Vault from the RoleManager.
            roleManager.newVault(
                address(hyperdrive.baseToken()),
                0,
                EVERLONG_NAME,
                EVERLONG_SYMBOL
            )
        );

        // Deploy the StrategyFactory.
        strategyFactory = new StrategyFactory(
            deployer,
            deployer,
            deployer,
            deployer
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

        // Add the Strategy to the Vault.
        debtAllocator.setMinimumWait(1);
        debtAllocator.setMinimumChange(address(vault), 1);
        debtAllocator.setStrategyDebtRatio(
            address(vault),
            address(strategy),
            10_000
        );

        console.log(
            "Latest Vault: %s",
            roleManager.latestVault(address(hyperdrive.baseToken()))
        );

        // Set the Everlong variable.
        everlong = EverlongExposed(address(vault));

        vm.stopPrank();

        // Fast forward and accrue some interest.
        advanceTimeWithCheckpoints(POSITION_DURATION * 2);

        console.log(
            "Vault Balance: %e",
            ERC20Mintable(everlong.asset()).balanceOf(address(everlong))
        );
        console.log(
            "Strategy Balance: %e",
            ERC20Mintable(everlong.asset()).balanceOf(address(strategy))
        );

        depositEverlong(10_000e18, alice, true);

        console.log(
            "Vault Balance: %e",
            ERC20Mintable(everlong.asset()).balanceOf(address(everlong))
        );
        console.log(
            "Strategy Balance: %e",
            ERC20Mintable(everlong.asset()).balanceOf(address(strategy))
        );

        vm.warp(block.timestamp + 1 days);
        vm.prank(deployer);
        debtAllocator.update_debt(address(vault), address(strategy), 10_000e18);
        revert("ahh");

        console.log(
            "Vault Balance: %e",
            ERC20Mintable(everlong.asset()).balanceOf(address(everlong))
        );
        console.log(
            "Strategy Balance: %e",
            ERC20Mintable(everlong.asset()).balanceOf(address(strategy))
        );

        vm.prank(deployer);
        debtAllocator.update_debt(address(vault), address(strategy), 10_000e18);

        console.log(
            "Balance: %e",
            ERC20Mintable(everlong.asset()).balanceOf(address(hyperdrive))
        );
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Deposit Helpers                                         │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Deposit into Everlong.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @return shares Amount of shares received from the deposit.
    function depositEverlong(
        uint256 _amount,
        address _depositor
    ) internal returns (uint256 shares) {
        return
            depositEverlong(
                _amount,
                _depositor,
                false,
                IEverlong.RebalanceOptions({
                    spendingLimit: 0,
                    minOutput: 0,
                    minVaultSharePrice: 0,
                    positionClosureLimit: 0,
                    extraData: ""
                })
            );
    }

    /// @dev Deposit into Everlong.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @param _shouldRebalance Whether to rebalance after the deposit is made.
    /// @return shares Amount of shares received from the deposit.
    function depositEverlong(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance
    ) internal returns (uint256 shares) {
        return
            depositEverlong(
                _amount,
                _depositor,
                _shouldRebalance,
                IEverlong.RebalanceOptions({
                    spendingLimit: 0,
                    minOutput: 0,
                    minVaultSharePrice: 0,
                    positionClosureLimit: 0,
                    extraData: ""
                })
            );
    }

    /// @dev Deposit into Everlong and rebalance after the deposit.
    /// @param _amount Amount of assets to deposit.
    /// @param _depositor Address to deposit as.
    /// @param _rebalanceOptions Options to pass to the rebalance call.
    /// @return shares Amount of shares received from the deposit.
    function depositEverlong(
        uint256 _amount,
        address _depositor,
        IEverlong.RebalanceOptions memory _rebalanceOptions
    ) internal returns (uint256 shares) {
        return depositEverlong(_amount, _depositor, true, _rebalanceOptions);
    }

    // NOTE: Core functionality for all `depositEverlong(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function depositEverlong(
        uint256 _amount,
        address _depositor,
        bool _shouldRebalance,
        IEverlong.RebalanceOptions memory _rebalanceOptions
    ) private returns (uint256 shares) {
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

        // Rebalance if specified.
        if (_shouldRebalance) {
            vm.startPrank(deployer);
            strategy.tend();
            vm.stopPrank();
            // rebalance(_rebalanceOptions);
        }

        // Return the amount of shares issued to _depositor for the deposit.
        return shares;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Redeem Helpers                                          │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Redeem shares from Everlong.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @return assets Amount of assets received from the redemption.
    function redeemEverlong(
        uint256 _shares,
        address _redeemer
    ) internal returns (uint256 assets) {
        assets = redeemEverlong(
            _shares,
            _redeemer,
            true,
            IEverlong.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        return assets;
    }

    /// @dev Redeem shares from Everlong.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @param _shouldRebalance Whether to rebalance after the redeem is made.
    /// @return assets Amount of assets received from the redemption.
    function redeemEverlong(
        uint256 _shares,
        address _redeemer,
        bool _shouldRebalance
    ) internal returns (uint256 assets) {
        assets = redeemEverlong(
            _shares,
            _redeemer,
            _shouldRebalance,
            IEverlong.RebalanceOptions({
                spendingLimit: 0,
                minOutput: 0,
                minVaultSharePrice: 0,
                positionClosureLimit: 0,
                extraData: ""
            })
        );
        return assets;
    }

    /// @dev Redeem shares from Everlong.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address to redeem as.
    /// @param _rebalanceOptions Options to pass to the rebalance call.
    /// @return assets Amount of assets received from the redemption.
    function redeemEverlong(
        uint256 _shares,
        address _redeemer,
        IEverlong.RebalanceOptions memory _rebalanceOptions
    ) internal returns (uint256 assets) {
        assets = redeemEverlong(_shares, _redeemer, true, _rebalanceOptions);
        return assets;
    }

    // NOTE: Core functionality for all `redeemEverlong(..)` overloads.
    //       This is the most verbose, probably don't want to call it directly.
    function redeemEverlong(
        uint256 _amount,
        address _redeemer,
        bool _shouldRebalance,
        IEverlong.RebalanceOptions memory _rebalanceOptions
    ) internal returns (uint256 proceeds) {
        // Make the redemption.
        vm.startPrank(_redeemer);
        proceeds = everlong.redeem(_amount, _redeemer, _redeemer);
        vm.stopPrank();

        // Rebalance if specified.
        if (_shouldRebalance) {
            vm.startPrank(deployer);
            strategy.tend();
            vm.stopPrank();
            // rebalance(_rebalanceOptions);
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
        ERC20Mintable(hyperdrive.baseToken()).approve(
            address(everlong),
            _amount
        );
        vm.stopPrank();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Rebalancing                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Call `everlong.rebalance(...)` as the admin with default options.
    function rebalance() internal virtual {
        // vm.startPrank(everlong.admin());
        // everlong.rebalance(DEFAULT_REBALANCE_OPTIONS);
        // vm.stopPrank();
        vm.startPrank(deployer);
        strategy.tend();
        vm.stopPrank();
    }

    /// @dev Call `everlong.rebalance(...)` as the admin with provided options.
    /// @param _options Rebalance options to pass to Everlong.
    function rebalance(
        IEverlong.RebalanceOptions memory _options
    ) internal virtual {
        // vm.startPrank(everlong.admin());
        // everlong.rebalance(_options);
        // vm.stopPrank();
        vm.startPrank(deployer);
        strategy.tend();
        vm.stopPrank();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Advance Time Helpers                                    │
    // ╰─────────────────────────────────────────────────────────╯

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
        IEverlong.RebalanceOptions memory _options
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
        IEverlong.RebalanceOptions memory _options
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
