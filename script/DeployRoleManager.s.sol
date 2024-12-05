// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { BaseDeployScript } from "./shared/BaseDeployScript.sol";
import { IAccountant } from "../contracts/interfaces/IAccountant.sol";
import { IRoleManager } from "../contracts/interfaces/IRoleManager.sol";
import { IRoleManagerFactory } from "../contracts/interfaces/IRoleManagerFactory.sol";
import { ROLE_MANAGER_FACTORY_ADDRESS } from "../contracts/libraries/Constants.sol";
import { DebtAllocator } from "vault-periphery/debtAllocators/DebtAllocator.sol";

contract DeployRoleManager is BaseDeployScript {
    // Required Arguments
    uint256 internal DEPLOYER_PRIVATE_KEY;
    uint256 internal GOVERNANCE_PRIVATE_KEY;
    uint256 internal MANAGEMENT_PRIVATE_KEY;

    // Optional Arguments
    string internal PROJECT_NAME;
    string internal constant PROJECT_NAME_DEFAULT = "DELV";

    // Artifact struct
    RoleManagerArtifact internal output;

    /// @dev Deploys a RoleManager and configures the default vault fee values
    ///      for the Accountant.
    function run() external {
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

        // Ensure output directory exists.
        require(
            vm.isDir(getRoleManagerArtifactDir()),
            string.concat(
                "Error: RoleManager artifact directory '",
                getRoleManagerArtifactDir(),
                "' has not been created"
            )
        );

        // Ensure output file does not exist.
        require(
            !vm.isFile(getRoleManagerArtifactPath(output.projectName)),
            string.concat(
                "Error: RoleManager artifact file '",
                getRoleManagerArtifactPath(output.projectName),
                "' already exists"
            )
        );

        // As the `deployer` account:
        //   1. Create a RoleManager from the factory.
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        output.roleManager = IRoleManagerFactory(ROLE_MANAGER_FACTORY_ADDRESS)
            .newProject(PROJECT_NAME, output.governance, output.management);
        vm.stopBroadcast();

        // Retrieve the default vault config from the Accountant.
        address accountant = IRoleManager(output.roleManager).getAccountant();
        IAccountant.Fee memory defaultConfig = IAccountant(accountant)
            .defaultConfig();

        // As the `governance` account:
        //   1. Accept the `FEE_MANAGER` role for the accountant contract.
        //   2. Update the default fee configuration for vaults to have no fees.
        vm.startBroadcast(GOVERNANCE_PRIVATE_KEY);
        IAccountant(accountant).acceptFeeManager();
        IAccountant(accountant).updateDefaultConfig(
            0, // Management Fee
            0, // Performance Fee
            0, // Refund Ratio to give back on losses
            0, // Max Fee
            defaultConfig.maxGain,
            defaultConfig.maxLoss
        );
        vm.stopBroadcast();

        // As the `management` account:
        //   1. Set the minimum wait time for updating strategy debt to zero.
        vm.startBroadcast(MANAGEMENT_PRIVATE_KEY);
        DebtAllocator(IRoleManager(output.roleManager).getDebtAllocator())
            .setMinimumWait(0);
        vm.stopBroadcast();

        // Write output in toml format to a file.
        writeRoleManagerArtifact(output);
    }
}
