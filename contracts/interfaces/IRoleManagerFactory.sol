// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

// WARN: Directly importing `RoleManagerFactory.sol` from vault-periphery results in
//       solidity compiler errors, so needed methods are copied here.
interface IRoleManagerFactory {
    struct Project {
        address roleManager;
        address registry;
        address accountant;
        address debtAllocator;
    }
    function newProject(
        string memory _name,
        address _governance,
        address _management
    ) external returns (address);

    function newRoleManager(
        string memory _projectName,
        address _governance,
        address _management,
        address _keeper,
        address _registry,
        address _accountant,
        address _debtAllocator
    ) external returns (address);

    function getProjectId(
        string memory _name,
        address _governance
    ) external view returns (bytes32);

    function projects(
        bytes32 _projectId
    ) external view returns (Project memory);
}
