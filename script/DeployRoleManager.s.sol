// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { IAccountant } from "../contracts/interfaces/IAccountant.sol";
import { IRoleManager } from "../contracts/interfaces/IRoleManager.sol";
import { IRoleManagerFactory } from "../contracts/interfaces/IRoleManagerFactory.sol";
import { ROLE_MANAGER_FACTORY_ADDRESS } from "../contracts/libraries/Constants.sol";

string constant ROLE_MANAGER_OUTPUT_DIR_NAME = "roleManagers";

struct DeployRoleManagerOutput {
    address accountant;
    address debtAllocator;
    address deployer;
    address governance;
    address management;
    string projectName;
    address roleManager;
    uint256 timestamp;
}

contract DeployRoleManager is Script {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                               Arguments                               │
    // ╰───────────────────────────────────────────────────────────────────────╯

    // ── Required ────────────────────────────────────────────────────────

    uint256 internal DEPLOYER_PRIVATE_KEY;
    uint256 internal GOVERNANCE_PRIVATE_KEY;
    uint256 internal MANAGEMENT_PRIVATE_KEY;

    // ── Optional ────────────────────────────────────────────────────────

    string internal PROJECT_NAME;
    string internal constant PROJECT_NAME_DEFAULT = "DELV";

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Output                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    DeployRoleManagerOutput internal output;

    /// @dev Ensures that `/deploy/${CHAIN_ID}/roleManagers` directory exists.
    function validateOutputDir() internal {
        string memory outputDir = string.concat(
            vm.projectRoot(),
            "/deploy/",
            vm.toString(block.chainid),
            "/",
            ROLE_MANAGER_OUTPUT_DIR_NAME
        );
        require(
            vm.isDir(outputDir),
            string.concat("ERROR: output dir '", outputDir, "' does not exist.")
        );
    }

    /// @dev `/deploy/${CHAIN_ID}/roleManagers/${PROJECT_NAME}.toml`
    function getOutputFilePath(
        string memory name
    ) internal view returns (string memory path) {
        path = string.concat(
            vm.projectRoot(),
            "/deploy/",
            vm.toString(block.chainid),
            "/",
            ROLE_MANAGER_OUTPUT_DIR_NAME,
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

        // Validate required arguments.
        require(
            output.governance != output.management,
            "governance and management accounts must be different"
        );

        // Read optional arguments.
        PROJECT_NAME = vm.envOr("PROJECT_NAME", PROJECT_NAME_DEFAULT);
        output.projectName = PROJECT_NAME;

        // Create a RoleManager from the factory as the deployer.
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        output.roleManager = IRoleManagerFactory(ROLE_MANAGER_FACTORY_ADDRESS)
            .newProject(PROJECT_NAME, output.governance, output.management);
        vm.stopBroadcast();

        // Retrieve the addresses of the DebtAllocator and Accountant periphery
        // contracts.
        output.accountant = IRoleManager(output.roleManager).getAccountant();
        output.debtAllocator = IRoleManager(output.roleManager).getAccountant();

        // Accept the `FEE_MANAGER` role for the accountant contract.
        // Update the default fee configuration for vaults to have no fees.
        IAccountant.Fee memory defaultConfig = IAccountant(output.accountant)
            .defaultConfig();
        vm.startBroadcast(GOVERNANCE_PRIVATE_KEY);
        IAccountant(output.accountant).acceptFeeManager();
        IAccountant(output.accountant).updateDefaultConfig(
            0, // Management Fee
            0, // Performance Fee
            0, // Refund Ratio to give back on losses
            0, // Max Fee
            defaultConfig.maxGain,
            defaultConfig.maxLoss
        );
        vm.stopBroadcast();

        // Write output in toml format to a file.
        string memory outputToml = "output";
        vm.serializeAddress(outputToml, "accountant", output.accountant);
        vm.serializeAddress(outputToml, "debtAllocator", output.debtAllocator);
        vm.serializeAddress(outputToml, "deployer", output.deployer);
        vm.serializeAddress(outputToml, "governance", output.governance);
        vm.serializeAddress(outputToml, "management", output.management);
        vm.serializeString(outputToml, "projectName", output.projectName);
        vm.serializeUint(outputToml, "timestamp", block.timestamp);
        string memory finalOutputToml = vm.serializeAddress(
            outputToml,
            "roleManager",
            output.roleManager
        );
        vm.writeToml(finalOutputToml, getOutputFilePath(output.projectName));
    }
}
