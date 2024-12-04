// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { IAccountant } from "../contracts/interfaces/IAccountant.sol";
import { IRoleManager } from "../contracts/interfaces/IRoleManager.sol";
import { IEverlongStrategy } from "../contracts/interfaces/IEverlongStrategy.sol";
import { IRoleManagerFactory } from "../contracts/interfaces/IRoleManagerFactory.sol";
import { EVERLONG_STRATEGY_KIND } from "../contracts/libraries/Constants.sol";
import { EverlongStrategy } from "../contracts/EverlongStrategy.sol";
import { EverlongStrategyKeeper } from "../contracts/EverlongStrategyKeeper.sol";
import { EVERLONG_KEEPER_CONTRACT_OUTPUT_DIR_NAME, DeployEverlongStrategyKeeperOutput } from "./DeployEverlongStrategyKeeper.s.sol";

string constant STRATEGY_OUTPUT_DIR_NAME = "strategies";

struct DeployEverlongStrategyOutput {
    bool asBase;
    address asset;
    address deployer;
    address emergencyAdmin;
    address governance;
    address hyperdrive;
    address keeperContract;
    string kind;
    address management;
    uint256 profitMaxUnlock;
    address strategy;
    string strategyName;
    uint256 timestamp;
}

contract DeployEverlongStrategyKeeper is Script {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                               Arguments                               │
    // ╰───────────────────────────────────────────────────────────────────────╯

    // ── Required ────────────────────────────────────────────────────────

    uint256 internal DEPLOYER_PRIVATE_KEY;
    uint256 internal GOVERNANCE_PRIVATE_KEY;
    uint256 internal MANAGEMENT_PRIVATE_KEY;
    uint256 internal EMERGENCY_ADMIN_PRIVATE_KEY;
    string internal STRATEGY_NAME;
    address internal HYPERDRIVE;

    // ── Optional ────────────────────────────────────────────────────────

    // AS_BASE

    bool internal AS_BASE;
    bool internal constant AS_BASE_DEFAULT = true;

    // PROFIT_MAX_UNLOCK

    uint256 internal PROFIT_MAX_UNLOCK;
    uint256 internal PROFIT_MAX_UNLOCK_DEFAULT = 0;

    // KEEPER_CONTRACT_ADDRESS

    address internal KEEPER_CONTRACT_ADDRESS;
    address internal KEEPER_CONTRACT_ADDRESS_DEFAULT;

    /// @dev Find the most-recently deployed EverlongStrategyKeeper on the same
    ///      chain and retrieve its address.
    function resolveDefaultKeeperContractAddress() internal {
        // Retrieve a list of all files and directories in the
        // `EverlongStrategyKeeper` script output directory.
        VmSafe.DirEntry[] memory entries = vm.readDir(
            string.concat(
                vm.projectRoot(),
                "/deploy/",
                vm.toString(block.chainid),
                "/",
                EVERLONG_KEEPER_CONTRACT_OUTPUT_DIR_NAME
            )
        );
        // Find the first path that isn't a directory, read the file contents,
        // and extract the `EverlongStrategyKeeper`'s address.
        // Use the most-recently deployed `EverlongStrategyKeeper`.
        DeployEverlongStrategyKeeperOutput
            memory deployEverlongStrategyKeeperOutput;
        for (uint256 i; i < entries.length; i++) {
            if (vm.isFile(entries[i].path)) {
                DeployEverlongStrategyKeeperOutput memory tmpOutput = abi
                    .decode(
                        vm.parseToml(vm.readFile(entries[i].path)),
                        (DeployEverlongStrategyKeeperOutput)
                    );
                if (
                    tmpOutput.timestamp >
                    deployEverlongStrategyKeeperOutput.timestamp
                ) {
                    deployEverlongStrategyKeeperOutput = tmpOutput;
                }
            }
        }
        KEEPER_CONTRACT_ADDRESS_DEFAULT = deployEverlongStrategyKeeperOutput
            .keeperContract;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Output                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    DeployEverlongStrategyOutput internal output;

    /// @dev Ensures that `/deploy/${CHAIN_ID}/strategies` dir exists.
    function validateOutputDir() internal {
        string memory outputDir = string.concat(
            vm.projectRoot(),
            "/deploy/",
            vm.toString(block.chainid),
            "/",
            STRATEGY_OUTPUT_DIR_NAME
        );
        require(
            vm.isDir(outputDir),
            string.concat("ERROR: output dir '", outputDir, "' does not exist.")
        );
    }

    /// @dev `/deploy/${CHAIN_ID}/strategies/${STRATEGY_NAME}.toml`
    function getOutputFilePath(
        string memory name
    ) internal view returns (string memory path) {
        path = string.concat(
            vm.projectRoot(),
            "/deploy/",
            vm.toString(block.chainid),
            "/",
            STRATEGY_OUTPUT_DIR_NAME,
            "/",
            name,
            ".toml"
        );
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                  Run                                  │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Deploys a RoleManager and configures the default vault fee values
    ///      for the Accountant.
    function run() external {
        // Ensure the output directory exists.
        validateOutputDir();

        // Read required arguments.
        DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
        output.deployer = vm.addr(DEPLOYER_PRIVATE_KEY);
        GOVERNANCE_PRIVATE_KEY = vm.envUint("GOVERNANCE_PRIVATE_KEY");
        output.governance = vm.addr(GOVERNANCE_PRIVATE_KEY);
        MANAGEMENT_PRIVATE_KEY = vm.envUint("MANAGEMENT_PRIVATE_KEY");
        output.management = vm.addr(MANAGEMENT_PRIVATE_KEY);
        EMERGENCY_ADMIN_PRIVATE_KEY = vm.envUint("EMERGENCY_ADMIN_PRIVATE_KEY");
        output.emergencyAdmin = vm.addr(EMERGENCY_ADMIN_PRIVATE_KEY);
        STRATEGY_NAME = vm.envString("STRATEGY_NAME");
        output.strategyName = STRATEGY_NAME;
        HYPERDRIVE = vm.envAddress("HYPERDRIVE");
        output.hyperdrive = HYPERDRIVE;

        // Validate required arguments.
        require(
            output.governance != output.management,
            "ERROR: governance and management accounts must be different"
        );
        require(
            !vm.isFile(getOutputFilePath(STRATEGY_NAME)),
            string.concat(
                "ERROR: An EverlongStrategy with name '",
                STRATEGY_NAME,
                "' already exists."
            )
        );

        // Resolve default values for optional arguments.
        resolveDefaultKeeperContractAddress();

        // Read optional arguments.
        AS_BASE = vm.envOr("AS_BASE", AS_BASE_DEFAULT);
        output.asBase = AS_BASE;
        PROFIT_MAX_UNLOCK = vm.envOr(
            "PROFIT_MAX_UNLOCK",
            PROFIT_MAX_UNLOCK_DEFAULT
        );
        output.profitMaxUnlock = PROFIT_MAX_UNLOCK;
        KEEPER_CONTRACT_ADDRESS = vm.envOr(
            "KEEPER_CONTRACT_ADDRESS",
            KEEPER_CONTRACT_ADDRESS_DEFAULT
        );
        output.keeperContract = KEEPER_CONTRACT_ADDRESS;

        // Validate optional arguments.
        require(
            output.keeperContract != address(0),
            "ERROR: KEEPER_CONTRACT_ADDRESS cannot be the zero address"
        );

        // Resolve the asset address.
        output.asset = output.asBase
            ? IHyperdrive(output.hyperdrive).baseToken()
            : IHyperdrive(output.hyperdrive).vaultSharesToken();

        // Save the strategy's kind to output.
        output.kind = EVERLONG_STRATEGY_KIND;

        // Deploy the EverlongStrategy contract.
        // Set the privileged addresses.
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        output.strategy = address(
            new EverlongStrategy(
                output.asset,
                output.strategyName,
                output.hyperdrive,
                output.asBase
            )
        );
        IEverlongStrategy(output.strategy).setPerformanceFeeRecipient(
            output.governance
        );
        IEverlongStrategy(output.strategy).setKeeper(output.keeperContract);
        IEverlongStrategy(output.strategy).setPendingManagement(
            output.management
        );
        IEverlongStrategy(output.strategy).setEmergencyAdmin(
            output.emergencyAdmin
        );
        vm.stopBroadcast();

        // Accept management responsibilities as the management address.
        // Set `profitMaxUnlock` and `performanceFee` for the strategy.
        vm.startBroadcast(MANAGEMENT_PRIVATE_KEY);
        IEverlongStrategy(output.strategy).acceptManagement();
        IEverlongStrategy(output.strategy).setProfitMaxUnlockTime(
            output.profitMaxUnlock
        );
        IEverlongStrategy(output.strategy).setPerformanceFee(0);
        vm.stopBroadcast();

        // Write output in toml format to a file.
        string memory outputToml = "output";
        vm.serializeBool(outputToml, "asBase", output.asBase);
        vm.serializeAddress(outputToml, "asset", output.asset);
        vm.serializeAddress(outputToml, "deployer", output.deployer);
        vm.serializeAddress(
            outputToml,
            "emergencyAdmin",
            output.emergencyAdmin
        );
        vm.serializeAddress(outputToml, "governance", output.governance);
        vm.serializeAddress(outputToml, "hyperdrive", output.hyperdrive);
        vm.serializeAddress(
            outputToml,
            "keeperContract",
            output.keeperContract
        );
        vm.serializeString(outputToml, "kind", output.kind);
        vm.serializeAddress(outputToml, "management", output.management);
        vm.serializeUint(outputToml, "profitMaxUnlock", output.profitMaxUnlock);
        vm.serializeAddress(outputToml, "strategy", output.strategy);
        vm.serializeString(outputToml, "strategyName", output.strategyName);
        string memory finalOutputToml = vm.serializeUint(
            outputToml,
            "timestamp",
            block.timestamp
        );
        vm.writeToml(finalOutputToml, getOutputFilePath(output.strategyName));
    }
}
