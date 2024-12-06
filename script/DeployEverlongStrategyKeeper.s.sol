// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { EverlongStrategyKeeper } from "../contracts/EverlongStrategyKeeper.sol";
import { COMMON_REPORT_TRIGGER_ADDRESS, EVERLONG_STRATEGY_KEEPER_KIND } from "../contracts/libraries/Constants.sol";
import { BaseDeployScript } from "./shared/BaseDeployScript.sol";

/// @title DeployEverlongStrategyKeeper
/// @notice EverlongStrategyKeeper deployment script.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract DeployEverlongStrategyKeeper is BaseDeployScript {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                          Required Arguments                           │
    // ╰───────────────────────────────────────────────────────────────────────╯
    /// @dev Deployer account private key;
    uint256 internal DEPLOYER_PRIVATE_KEY;
    /// @dev Keeper account private key;
    uint256 internal KEEPER_PRIVATE_KEY;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                          Optional Arguments                           │
    // ╰───────────────────────────────────────────────────────────────────────╯
    /// @dev Name of the keeper contract.
    string internal NAME;
    string internal constant NAME_DEFAULT = "EVERLONG_STRATEGY_KEEPER";

    /// @dev Name of the project used to create the RoleManager.
    string internal ROLE_MANAGER_PROJECT_NAME;
    string internal ROLE_MANAGER_PROJECT_NAME_DEFAULT;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                            Artifact Struct                            │
    // ╰───────────────────────────────────────────────────────────────────────╯
    /// @dev Struct containing deployment artifact information.
    KeeperContractArtifact internal output;

    /// @dev Deploys an EverlongStrategyKeeper.
    function run() external {
        // Read required arguments.
        DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
        output.deployer = vm.addr(DEPLOYER_PRIVATE_KEY);
        KEEPER_PRIVATE_KEY = vm.envUint("KEEPER_PRIVATE_KEY");
        output.keeper = vm.addr(KEEPER_PRIVATE_KEY);

        // Validate required arguments.
        require(
            output.deployer != output.keeper,
            "Error: deployer and keeper accounts must be different"
        );

        // Resolve optional argument defaults.
        ROLE_MANAGER_PROJECT_NAME_DEFAULT = hasDefaultRoleManagerArtifact()
            ? getDefaultRoleManagerArtifact().projectName
            : "";

        // Read optional arguments.
        NAME = vm.envOr("NAME", NAME_DEFAULT);
        output.name = NAME;
        ROLE_MANAGER_PROJECT_NAME = vm.envOr(
            "ROLE_MANAGER_PROJECT_NAME",
            ROLE_MANAGER_PROJECT_NAME_DEFAULT
        );
        output.roleManagerProjectName = ROLE_MANAGER_PROJECT_NAME;

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

        // Include the KeeperContract's `kind` in the artifact.
        output.kind = EVERLONG_STRATEGY_KEEPER_KIND;

        // Ensure output directory exists.
        require(
            vm.isDir(getKeeperContractArtifactDir()),
            string.concat(
                "Error: KeeperContract artifact directory '",
                getKeeperContractArtifactDir(),
                "' has not been created"
            )
        );

        // Ensure output file does not exist.
        require(
            !vm.isFile(getKeeperContractArtifactPath(output.name)),
            string.concat(
                "Error: KeeperContract artifact file '",
                getKeeperContractArtifactPath(output.name),
                "' already exists"
            )
        );

        // As the `deployer` account:
        //   1. Deploy the KeeperContract.
        //   2. Transfer ownership to the `keeper` account.
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        output.keeperContract = address(
            new EverlongStrategyKeeper(
                output.name,
                roleManagerAddress,
                COMMON_REPORT_TRIGGER_ADDRESS
            )
        );
        EverlongStrategyKeeper(output.keeperContract).transferOwnership(
            output.keeper
        );
        vm.stopBroadcast();

        // Write output in toml format to a file.
        writeKeeperContractArtifact(output);
    }
}
