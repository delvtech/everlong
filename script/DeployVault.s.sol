// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";
import { DebtAllocator } from "vault-periphery/debtAllocators/DebtAllocator.sol";
import { IVault } from "yearn-vaults-v3/interfaces/IVault.sol";
import { IPermissionedStrategy } from "../contracts/interfaces/IPermissionedStrategy.sol";
import { IRoleManager } from "../contracts/interfaces/IRoleManager.sol";
import { EVERLONG_STRATEGY_KIND, MAX_BPS } from "../contracts/libraries/Constants.sol";
import { BaseDeployScript } from "./shared/BaseDeployScript.sol";

/// @title DeployVault
/// @notice Vault deployment script.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract DeployVault is BaseDeployScript {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                          Required Arguments                           │
    // ╰───────────────────────────────────────────────────────────────────────╯
    /// @dev Deployer account private key;
    uint256 internal GOVERNANCE_PRIVATE_KEY;
    /// @dev Management account private key;
    uint256 internal MANAGEMENT_PRIVATE_KEY;
    /// @dev Name of the strategy for the vault to deposit assets into.
    string internal STRATEGY_NAME;
    /// @dev Name for the vault.
    string internal NAME;
    /// @dev Symbol for the vault.
    string internal SYMBOL;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                          Optional Arguments                           │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Category for the vault.
    /// @dev Yearn docs state that vaults with a category of 0 are arbitrary,
    ///      however a category of 1 indicates lowest risk. Whatever method we
    ///      choose, let's try to be consistent.
    uint256 internal CATEGORY;
    uint256 internal CATEGORY_DEFAULT = 0;

    /// @dev ProfitMaxUnlock for the vault. Should be the same interval that the
    ///      underlying yield source accrues on.
    uint256 internal PROFIT_MAX_UNLOCK;
    uint256 internal PROFIT_MAX_UNLOCK_DEFAULT = 1 days;

    /// @dev Minimum idle liquidity for the vault.
    uint256 internal MIN_IDLE_LIQUIDITY;
    uint256 internal MIN_IDLE_LIQUIDITY_DEFAULT = 500; // 5%

    /// @dev Target idle liquidity for the vault.
    uint256 internal TARGET_IDLE_LIQUIDITY;
    uint256 internal TARGET_IDLE_LIQUIDITY_DEFAULT = 1000; // 10%

    /// @dev Minimum change in assets to trigger debt updates..
    uint256 internal MIN_CHANGE;
    uint256 internal MIN_CHANGE_DEFAULT;

    /// @dev Name of the project used to create the RoleManager.
    string internal ROLE_MANAGER_PROJECT_NAME;
    string internal ROLE_MANAGER_PROJECT_NAME_DEFAULT;

    /// @dev Name of the keeper contract to use for the vault. Should be the
    ///      same keeper contract as the underlying strategy.
    string internal KEEPER_CONTRACT_NAME;
    string internal KEEPER_CONTRACT_NAME_DEFAULT;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                           Artifact Struct.                            │
    // ╰───────────────────────────────────────────────────────────────────────╯
    /// @dev Struct containing deployment artifact information.
    VaultArtifact internal output;

    /// @dev Deploys and configures a Vault.
    function run() external {
        // Read required arguments.
        GOVERNANCE_PRIVATE_KEY = vm.envUint("GOVERNANCE_PRIVATE_KEY");
        output.governance = vm.addr(GOVERNANCE_PRIVATE_KEY);
        MANAGEMENT_PRIVATE_KEY = vm.envUint("MANAGEMENT_PRIVATE_KEY");
        output.management = vm.addr(MANAGEMENT_PRIVATE_KEY);
        STRATEGY_NAME = vm.envString("STRATEGY_NAME");
        output.strategyName = STRATEGY_NAME;
        NAME = vm.envString("NAME");
        output.name = NAME;
        SYMBOL = vm.envString("SYMBOL");
        output.symbol = SYMBOL;

        // Validate required arguments.
        require(
            output.governance != output.management,
            "ERROR: governance and management accounts must be different"
        );
        require(
            vm.isFile(getStrategyArtifactPath(output.strategyName)),
            "ERROR: STRATEGY_NAME cannot be found in artifacts"
        );
        StrategyArtifact memory strategyArtifact = getStrategyArtifact(
            output.strategyName
        );
        require(
            keccak256(bytes(strategyArtifact.kind)) ==
                keccak256(bytes(EVERLONG_STRATEGY_KIND)),
            string.concat(
                "ERROR: strategy kind '",
                strategyArtifact.kind,
                "' does not match '",
                EVERLONG_STRATEGY_KIND,
                "'"
            )
        );
        address strategyAddress = strategyArtifact.strategy;

        // Resolve optional argument defaults.
        MIN_CHANGE_DEFAULT =
            IHyperdrive(strategyArtifact.hyperdrive)
                .getPoolConfig()
                .minimumTransactionAmount +
            1;
        ROLE_MANAGER_PROJECT_NAME_DEFAULT = hasDefaultRoleManagerArtifact()
            ? getDefaultRoleManagerArtifact().projectName
            : "";
        KEEPER_CONTRACT_NAME_DEFAULT = vm.isFile(
            getKeeperContractArtifactPath(strategyArtifact.keeperContractName)
        )
            ? strategyArtifact.keeperContractName
            : "";

        // Read optional arguments.
        CATEGORY = vm.envOr("CATEGORY", CATEGORY_DEFAULT);
        PROFIT_MAX_UNLOCK = vm.envOr(
            "PROFIT_MAX_UNLOCK",
            PROFIT_MAX_UNLOCK_DEFAULT
        );
        MIN_IDLE_LIQUIDITY = vm.envOr(
            "MIN_IDLE_LIQUIDITY",
            MIN_IDLE_LIQUIDITY_DEFAULT
        );
        TARGET_IDLE_LIQUIDITY = vm.envOr(
            "TARGET_IDLE_LIQUIDITY",
            TARGET_IDLE_LIQUIDITY_DEFAULT
        );
        MIN_CHANGE = vm.envOr("MIN_CHANGE", MIN_CHANGE_DEFAULT);
        ROLE_MANAGER_PROJECT_NAME = vm.envOr(
            "ROLE_MANAGER_PROJECT_NAME",
            ROLE_MANAGER_PROJECT_NAME_DEFAULT
        );
        output.roleManagerProjectName = ROLE_MANAGER_PROJECT_NAME;
        KEEPER_CONTRACT_NAME = vm.envOr(
            "KEEPER_CONTRACT_NAME",
            KEEPER_CONTRACT_NAME_DEFAULT
        );
        output.keeperContractName = KEEPER_CONTRACT_NAME;

        // Validate optional arguments.
        require(
            vm.isFile(
                getRoleManagerArtifactPath(output.roleManagerProjectName)
            ),
            "ERROR: ROLE_MANAGER_PROJECT_NAME cannot be found in artifacts"
        );
        address roleManagerAddress = getRoleManagerArtifact(
            output.roleManagerProjectName
        ).roleManager;
        require(
            vm.isFile(getKeeperContractArtifactPath(output.keeperContractName)),
            "ERROR: KEEPER_CONTRACT_NAME cannot be found in artifacts"
        );
        address keeperContractAddress = getKeeperContractArtifact(
            output.keeperContractName
        ).keeperContract;

        // As the `governance` address:
        //   1. Deploy the vault.
        //   2. Add the strategy to the vault.
        //   3. Update the max debt for the strategy (defaults to zero).
        //   4. Give the keeperContract the `KEEPER` role.
        vm.startBroadcast(GOVERNANCE_PRIVATE_KEY);
        // Deploy the vault.
        IVault vault = IVault(
            IRoleManager(roleManagerAddress).newVault(
                IStrategy(strategyAddress).asset(),
                CATEGORY,
                output.name,
                output.symbol
            )
        );
        output.vault = address(vault);
        // Add the strategy to the vault.
        vault.add_strategy(strategyAddress);
        // Update max debt for the strategy.
        vault.update_max_debt_for_strategy(strategyAddress, type(uint256).max);
        // Give the keeper contract the `KEEPER` role.
        IRoleManager(roleManagerAddress).setPositionHolder(
            IRoleManager(roleManagerAddress).KEEPER(),
            keeperContractAddress
        );
        vm.stopBroadcast();

        // Retrieve the RoleManager's DebtAllocator.
        DebtAllocator debtAllocator = DebtAllocator(
            IRoleManager(roleManagerAddress).getDebtAllocator()
        );

        // As the `management` address:
        //   1. Set the profitMaxUnlock time.
        //   2. Add the vault as a depositor to the strategy.
        //   3. Set the keeperContract as a keeper in the DebtAllocator.
        //   4. Set the minimumWait for updating strategy debt.
        //   5. Set the minimumChange for updating strategy debt.
        //   6. Configure idle liquidity parameters for the vault.
        vm.startBroadcast(MANAGEMENT_PRIVATE_KEY);
        // Set the profitMaxUnlock time.
        vault.setProfitMaxUnlockTime(PROFIT_MAX_UNLOCK);
        // Add the vault as a depositor to the strategy.
        IPermissionedStrategy(strategyAddress).setDepositor(
            address(vault),
            true
        );
        // Set the keeperContract as a keeper in the DebtAllocator.
        debtAllocator.setKeeper(keeperContractAddress, true);
        // Set the minimumChange for updating strategy debt.
        debtAllocator.setMinimumChange(address(vault), MIN_CHANGE);
        // Configure idle liquidity parameters for the vault.
        debtAllocator.setStrategyDebtRatio(
            address(vault),
            strategyAddress,
            MAX_BPS - TARGET_IDLE_LIQUIDITY,
            MAX_BPS - MIN_IDLE_LIQUIDITY
        );
        vm.stopBroadcast();

        writeVaultArtifact(output);
    }
}
