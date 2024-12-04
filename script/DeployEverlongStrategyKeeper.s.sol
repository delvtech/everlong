// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import { IAccountant } from "../contracts/interfaces/IAccountant.sol";
import { IRoleManager } from "../contracts/interfaces/IRoleManager.sol";
import { IRoleManagerFactory } from "../contracts/interfaces/IRoleManagerFactory.sol";
import { ROLE_MANAGER_FACTORY_ADDRESS, COMMON_REPORT_TRIGGER_ADDRESS } from "../contracts/libraries/Constants.sol";
import { EverlongStrategyKeeper } from "../contracts/EverlongStrategyKeeper.sol";
import { ROLE_MANAGER_OUTPUT_DIR_NAME, DeployRoleManagerOutput } from "./DeployRoleManager.s.sol";

string constant KEEPER_CONTRACT_OUTPUT_DIR_NAME = "keeperContracts";

struct DeployEverlongStrategyKeeperOutput {
    address commonReportTrigger;
    address deployer;
    address keeper;
    address keeperContract;
    string keeperContractName;
    address roleManager;
    uint256 timestamp;
}

contract DeployEverlongStrategyKeeper is Script {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                               Arguments                               │
    // ╰───────────────────────────────────────────────────────────────────────╯
    // ────────────────────────────── REQUIRED ───────────────────────────
    uint256 internal DEPLOYER_PRIVATE_KEY;
    uint256 internal KEEPER_PRIVATE_KEY;

    // ────────────────────────────── OPTIONAL ───────────────────────────

    // KEEPER_CONTRACT_NAME
    string internal KEEPER_CONTRACT_NAME;
    string internal constant KEEPER_CONTRACT_NAME_DEFAULT =
        "EVERLONG_STRATEGY_KEEPER";

    // ROLE_MANAGER_ADDRESS
    address internal ROLE_MANAGER_ADDRESS;
    address internal ROLE_MANAGER_ADDRESS_DEFAULT;

    /// @dev Find the most-recently deployed RoleManager on the same chain and
    ///      retrieve its address.
    function resolveDefaultRoleManagerAddress() internal {
        // Retrieve a list of all files and directories in the `DeployRoleManager`
        // script output directory.
        VmSafe.DirEntry[] memory entries = vm.readDir(
            string.concat(
                vm.projectRoot(),
                "/deploy/",
                vm.toString(block.chainid),
                "/",
                ROLE_MANAGER_OUTPUT_DIR_NAME
            )
        );
        // Find the first path that isn't a directory, read the file contents,
        // and extract the `RoleManager`'s address.
        // Use the most-recently deployed `RoleManager`.
        DeployRoleManagerOutput memory deployRoleManagerOutput;
        for (uint256 i; i < entries.length; i++) {
            if (vm.isFile(entries[i].path)) {
                DeployRoleManagerOutput memory tmpOutput = abi.decode(
                    vm.parseToml(vm.readFile(entries[i].path)),
                    (DeployRoleManagerOutput)
                );
                if (tmpOutput.timestamp > deployRoleManagerOutput.timestamp) {
                    deployRoleManagerOutput = tmpOutput;
                }
            }
        }
        ROLE_MANAGER_ADDRESS_DEFAULT = deployRoleManagerOutput.roleManager;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Output                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯
    DeployEverlongStrategyKeeperOutput internal output;

    /// @dev Ensures that `/deploy/${CHAIN_ID}/keeperContracts` exists.
    function validateOutputDir() internal {
        string memory outputDir = string.concat(
            vm.projectRoot(),
            "/deploy/",
            vm.toString(block.chainid),
            "/",
            KEEPER_CONTRACT_OUTPUT_DIR_NAME
        );
        require(
            vm.isDir(outputDir),
            string.concat("ERROR: output dir '", outputDir, "' does not exist.")
        );
    }

    /// @dev `/deploy/${CHAIN_ID}/keeperContracts/${KEEPER_CONTRACT_NAME}.toml`
    function getOutputFilePath(
        string memory name
    ) internal view returns (string memory path) {
        path = string.concat(
            vm.projectRoot(),
            "/deploy/",
            vm.toString(block.chainid),
            "/",
            KEEPER_CONTRACT_OUTPUT_DIR_NAME,
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
        KEEPER_PRIVATE_KEY = vm.envUint("KEEPER_PRIVATE_KEY");
        output.keeper = vm.addr(KEEPER_PRIVATE_KEY);

        // Validate required arguments.
        require(
            output.deployer != output.keeper,
            "deployer and keeper accounts must be different"
        );

        // Resolve optional argument defaults.
        resolveDefaultRoleManagerAddress();

        // Read optional arguments.
        KEEPER_CONTRACT_NAME = vm.envOr(
            "KEEPER_CONTRACT_NAME",
            KEEPER_CONTRACT_NAME_DEFAULT
        );
        output.keeperContractName = KEEPER_CONTRACT_NAME;
        ROLE_MANAGER_ADDRESS = vm.envOr(
            "ROLE_MANAGER_ADDRESS",
            ROLE_MANAGER_ADDRESS_DEFAULT
        );
        output.roleManager = ROLE_MANAGER_ADDRESS;

        // Validate optional arguments.
        require(
            ROLE_MANAGER_ADDRESS != address(0),
            "ROLE_MANAGER_ADDRESS cannot be the zero address"
        );
        require(
            !vm.isFile(getOutputFilePath(KEEPER_CONTRACT_NAME)),
            string.concat(
                "ERROR: An EverlongStrategyKeeper with name '",
                KEEPER_CONTRACT_NAME,
                "' already exists."
            )
        );

        // Deploy the EverlongStrategyKeeper contract.
        // Transfer ownership to the `keeper` address.
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        output.keeperContract = address(
            new EverlongStrategyKeeper(
                output.keeperContractName,
                output.roleManager,
                COMMON_REPORT_TRIGGER_ADDRESS
            )
        );
        EverlongStrategyKeeper(output.keeperContract).transferOwnership(
            output.keeper
        );
        vm.stopBroadcast();
        output.commonReportTrigger = COMMON_REPORT_TRIGGER_ADDRESS;

        // Write output in toml format to a file.
        string memory outputToml = "output";
        vm.serializeAddress(
            outputToml,
            "commonReportTrigger",
            output.commonReportTrigger
        );
        vm.serializeAddress(outputToml, "deployer", output.deployer);
        vm.serializeAddress(outputToml, "keeper", output.keeper);
        vm.serializeAddress(
            outputToml,
            "keeperContract",
            output.keeperContract
        );
        vm.serializeString(
            outputToml,
            "keeperContractName",
            output.keeperContractName
        );
        vm.serializeAddress(outputToml, "roleManager", output.roleManager);
        string memory finalOutputToml = vm.serializeUint(
            outputToml,
            "timestamp",
            block.timestamp
        );
        vm.writeToml(
            finalOutputToml,
            getOutputFilePath(output.keeperContractName)
        );
    }
}
