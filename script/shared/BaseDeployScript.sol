// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { Script, VmSafe } from "forge-std/Script.sol";
import { IRoleManager } from "../../contracts/interfaces/IRoleManager.sol";

/// @title BaseDeployScript
/// @notice Deploy scripting utilities.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract BaseDeployScript is Script {
    /// @dev Returns the base directory for deployment artifacts for the current
    ///      chain.
    function getBaseArtifactDir() internal view returns (string memory) {
        return
            string.concat(
                vm.projectRoot(),
                "/deploy/",
                vm.toString(block.chainid),
                "/"
            );
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              RoleManager                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Directory for RoleManager artifacts.
    string internal constant ROLE_MANAGER_DIR_NAME = "roleManagers/";

    /// @dev RoleManager artifact fields.
    struct RoleManagerArtifact {
        address deployer;
        address governance;
        address management;
        string projectName;
        address roleManager;
        uint256 timestamp;
    }

    /// @dev Returns the full path to the RoleManager artifact directory for
    ///      the current chain.
    function getRoleManagerArtifactDir() internal view returns (string memory) {
        return string.concat(getBaseArtifactDir(), ROLE_MANAGER_DIR_NAME);
    }

    /// @dev Returns the full path to the RoleManagerArtifact for the current
    ///      chain.
    function getRoleManagerArtifactPath(
        string memory _projectName
    ) internal view returns (string memory) {
        return
            string.concat(getRoleManagerArtifactDir(), _projectName, ".toml");
    }

    /// @dev Parses the RoleManagerArtifact at the provided path into the
    ///      RoleManagerArtifact struct.
    function readRoleManagerArtifact(
        string memory _path
    ) internal view returns (RoleManagerArtifact memory artifact) {
        artifact = abi.decode(
            vm.parseToml(vm.readFile(_path)),
            (RoleManagerArtifact)
        );
    }

    /// @dev Writes the provided RoleManagerArtifact to a toml file.
    function writeRoleManagerArtifact(
        RoleManagerArtifact memory _artifact
    ) internal {
        string memory outputToml = "output";
        vm.serializeAddress(outputToml, "deployer", _artifact.deployer);
        vm.serializeAddress(outputToml, "governance", _artifact.governance);
        vm.serializeAddress(outputToml, "management", _artifact.management);
        vm.serializeString(outputToml, "projectName", _artifact.projectName);
        vm.serializeAddress(outputToml, "roleManager", _artifact.roleManager);
        string memory finalOutputToml = vm.serializeUint(
            outputToml,
            "timestamp",
            block.timestamp
        );
        vm.writeToml(
            finalOutputToml,
            getRoleManagerArtifactPath(_artifact.projectName)
        );
    }

    /// @dev Returns true if a RoleManagerArtifact exists for the current chain,
    ///      false otherwise.
    function hasDefaultRoleManagerArtifact() internal view returns (bool) {
        VmSafe.DirEntry[] memory entries = vm.readDir(
            getRoleManagerArtifactDir()
        );
        return entries.length > 0;
    }

    /// @dev Returns the default RoleManagerArtifact for the current chain.
    function getDefaultRoleManagerArtifact()
        internal
        returns (RoleManagerArtifact memory)
    {
        VmSafe.DirEntry[] memory entries = vm.readDir(
            getRoleManagerArtifactDir()
        );
        RoleManagerArtifact memory roleManagerArtifact;
        for (uint256 i; i < entries.length; i++) {
            if (vm.isFile(entries[i].path)) {
                RoleManagerArtifact memory tmpOutput = abi.decode(
                    vm.parseToml(vm.readFile(entries[i].path)),
                    (RoleManagerArtifact)
                );
                if (tmpOutput.timestamp > roleManagerArtifact.timestamp) {
                    roleManagerArtifact = tmpOutput;
                }
            }
        }
        return roleManagerArtifact;
    }

    /// @dev Returns the RoleManagerArtifact with the provided name.
    function getRoleManagerArtifact(
        string memory _projectName
    ) internal view returns (RoleManagerArtifact memory) {
        return
            readRoleManagerArtifact(getRoleManagerArtifactPath(_projectName));
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                           Keeper Contracts                            │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Directory for KeeperContractArtifacts.
    string constant KEEPER_CONTRACT_DIR_NAME = "keeperContracts/";

    /// @dev Keeper contract artifact fields.
    struct KeeperContractArtifact {
        address deployer;
        address keeper;
        address keeperContract;
        string kind;
        string name;
        string roleManagerProjectName;
        uint256 timestamp;
    }

    /// @dev Returns the full path to the KeeperContractArtifact directory for
    ///      the current chain.
    function getKeeperContractArtifactDir()
        internal
        view
        returns (string memory)
    {
        return string.concat(getBaseArtifactDir(), KEEPER_CONTRACT_DIR_NAME);
    }

    /// @dev Returns the full path to the KeeperContractArtifact for the current
    ///      chain.
    function getKeeperContractArtifactPath(
        string memory _name
    ) internal view returns (string memory) {
        return string.concat(getKeeperContractArtifactDir(), _name, ".toml");
    }

    /// @dev Parses the KeeperContractArtifact at the provided path into the
    ///      KeeperContractArtifact struct.
    function readKeeperContractArtifact(
        string memory _path
    ) internal view returns (KeeperContractArtifact memory artifact) {
        artifact = abi.decode(
            vm.parseToml(vm.readFile(_path)),
            (KeeperContractArtifact)
        );
    }

    /// @dev Writes the provided KeeperContractArtifact to a toml file.
    function writeKeeperContractArtifact(
        KeeperContractArtifact memory _artifact
    ) internal {
        string memory outputToml = "output";
        vm.serializeAddress(outputToml, "deployer", _artifact.deployer);
        vm.serializeAddress(outputToml, "keeper", _artifact.keeper);
        vm.serializeAddress(
            outputToml,
            "keeperContract",
            _artifact.keeperContract
        );
        vm.serializeString(outputToml, "kind", _artifact.kind);
        vm.serializeString(outputToml, "name", _artifact.name);
        vm.serializeString(
            outputToml,
            "roleManagerProjectName",
            _artifact.roleManagerProjectName
        );
        string memory finalOutputToml = vm.serializeUint(
            outputToml,
            "timestamp",
            block.timestamp
        );
        vm.writeToml(
            finalOutputToml,
            getKeeperContractArtifactPath(_artifact.name)
        );
    }

    /// @dev Returns true if a KeeperContractArtifact exists for the current
    ///      chain, false otherwise.
    function hasDefaultKeeperContractArtifact(
        string memory _kind
    ) internal view returns (bool) {
        VmSafe.DirEntry[] memory entries = vm.readDir(
            getKeeperContractArtifactDir()
        );
        KeeperContractArtifact memory tmp;
        for (uint256 i; i < entries.length; i++) {
            tmp = abi.decode(
                vm.parseToml(vm.readFile(entries[i].path)),
                (KeeperContractArtifact)
            );
            if (keccak256(bytes(tmp.kind)) == keccak256(bytes(_kind))) {
                return true;
            }
        }
        return false;
    }

    /// @dev Returns the default KeeperContractArtifact for the current chain.
    function getDefaultKeeperContractArtifact(
        string memory _kind
    ) internal returns (KeeperContractArtifact memory) {
        VmSafe.DirEntry[] memory entries = vm.readDir(
            getKeeperContractArtifactDir()
        );
        KeeperContractArtifact memory keeperContractArtifact;
        for (uint256 i; i < entries.length; i++) {
            if (vm.isFile(entries[i].path)) {
                KeeperContractArtifact memory tmp = abi.decode(
                    vm.parseToml(vm.readFile(entries[i].path)),
                    (KeeperContractArtifact)
                );
                if (
                    keccak256(bytes(tmp.kind)) == keccak256(bytes(_kind)) &&
                    tmp.timestamp > keeperContractArtifact.timestamp
                ) {
                    keeperContractArtifact = tmp;
                }
            }
        }
        return keeperContractArtifact;
    }

    /// @dev Returns the KeeperContractArtifact with the provided name.
    function getKeeperContractArtifact(
        string memory _name
    ) internal view returns (KeeperContractArtifact memory) {
        return readKeeperContractArtifact(getKeeperContractArtifactPath(_name));
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              Strategies                               │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Directory for StrategyArtifacts.
    string constant STRATEGY_DIR_NAME = "strategies/";

    /// @dev Strategy artifact fields.
    struct StrategyArtifact {
        address deployer;
        address emergencyAdmin;
        address governance;
        address hyperdrive;
        string keeperContractName;
        string kind;
        address management;
        string name;
        address strategy;
        uint256 timestamp;
    }

    /// @dev Returns the full path to the StrategyArtifact directory for
    ///      the current chain.
    function getStrategyArtifactDir() internal view returns (string memory) {
        return string.concat(getBaseArtifactDir(), STRATEGY_DIR_NAME);
    }

    /// @dev Returns the full path to the StrategyArtifact for the current
    ///      chain.
    function getStrategyArtifactPath(
        string memory _name
    ) internal view returns (string memory) {
        return string.concat(getStrategyArtifactDir(), _name, ".toml");
    }

    /// @dev Parses the StrategyArtifact at the provided path into the
    ///      StrategyArtifact struct.
    function readStrategyArtifact(
        string memory _path
    ) internal view returns (StrategyArtifact memory artifact) {
        artifact = abi.decode(
            vm.parseToml(vm.readFile(_path)),
            (StrategyArtifact)
        );
    }

    /// @dev Writes the provided StrategyArtifact to a toml file.
    function writeStrategyArtifact(StrategyArtifact memory _artifact) internal {
        string memory outputToml = "output";
        vm.serializeAddress(outputToml, "deployer", _artifact.deployer);
        vm.serializeAddress(
            outputToml,
            "emergencyAdmin",
            _artifact.emergencyAdmin
        );
        vm.serializeAddress(outputToml, "governance", _artifact.governance);
        vm.serializeAddress(outputToml, "hyperdrive", _artifact.hyperdrive);
        vm.serializeString(
            outputToml,
            "keeperContractName",
            _artifact.keeperContractName
        );
        vm.serializeString(outputToml, "kind", _artifact.kind);
        vm.serializeAddress(outputToml, "management", _artifact.management);
        vm.serializeString(outputToml, "name", _artifact.name);
        vm.serializeAddress(outputToml, "strategy", _artifact.strategy);
        string memory finalOutputToml = vm.serializeUint(
            outputToml,
            "timestamp",
            block.timestamp
        );
        vm.writeToml(finalOutputToml, getStrategyArtifactPath(_artifact.name));
    }

    /// @dev Returns the StrategyArtifact with the provided name.
    function getStrategyArtifact(
        string memory _name
    ) internal view returns (StrategyArtifact memory) {
        return readStrategyArtifact(getStrategyArtifactPath(_name));
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Vaults                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Directory for VaultArtifacts.
    string constant VAULT_DIR_NAME = "vaults/";

    /// @dev Vault artifact fields.
    struct VaultArtifact {
        address governance;
        string keeperContractName;
        address management;
        string name;
        string roleManagerProjectName;
        string strategyName;
        string symbol;
        uint256 timestamp;
        address vault;
    }

    /// @dev Returns the full path to the VaultArtifact directory for
    ///      the current chain.
    function getVaultArtifactDir() internal view returns (string memory) {
        return string.concat(getBaseArtifactDir(), VAULT_DIR_NAME);
    }

    /// @dev Returns the full path to the VaultArtifact for the current
    ///      chain.
    function getVaultArtifactPath(
        string memory _name
    ) internal view returns (string memory) {
        return string.concat(getVaultArtifactDir(), _name, ".toml");
    }

    /// @dev Parses the VaultArtifact at the provided path into the
    ///      VaultArtifact struct.
    function readVaultArtifact(
        string memory _path
    ) internal view returns (VaultArtifact memory artifact) {
        artifact = abi.decode(
            vm.parseToml(vm.readFile(_path)),
            (VaultArtifact)
        );
    }

    /// @dev Writes the provided VaultArtifact to a toml file.
    function writeVaultArtifact(VaultArtifact memory _artifact) internal {
        string memory outputToml = "output";
        vm.serializeAddress(outputToml, "governance", _artifact.governance);
        vm.serializeString(
            outputToml,
            "keeperContractName",
            _artifact.keeperContractName
        );
        vm.serializeAddress(outputToml, "management", _artifact.management);
        vm.serializeString(outputToml, "name", _artifact.name);
        vm.serializeString(
            outputToml,
            "roleManagerProjectName",
            _artifact.roleManagerProjectName
        );
        vm.serializeString(outputToml, "strategyName", _artifact.strategyName);
        vm.serializeString(outputToml, "symbol", _artifact.symbol);
        vm.serializeUint(outputToml, "timestamp", block.timestamp);
        string memory finalOutputToml = vm.serializeAddress(
            outputToml,
            "vault",
            _artifact.vault
        );
        vm.writeToml(finalOutputToml, getVaultArtifactPath(_artifact.name));
    }

    /// @dev Returns the VaultArtifact with the provided name.
    function getVaultArtifact(
        string memory _name
    ) internal view returns (VaultArtifact memory) {
        return readVaultArtifact(getVaultArtifactPath(_name));
    }
}
