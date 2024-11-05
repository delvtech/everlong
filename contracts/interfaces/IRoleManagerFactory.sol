// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IRoleManagerFactory {
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
}
