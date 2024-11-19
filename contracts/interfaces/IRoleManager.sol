// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

// WARN: Directly importing `RoleManager.sol` from vault-periphery results in
//       solidity compiler errors, so needed methods are copied here.
interface IRoleManager {
    // ╭─────────────────────────────────────────────────────────╮
    // │ VAULT CREATION                                          │
    // ╰─────────────────────────────────────────────────────────╯

    /**
     * @notice Creates a new endorsed vault with default profit max unlock time.
     * @param _asset Address of the underlying asset.
     * @param _category Category of the vault.
     * @param _name Name of the vault.
     * @param _symbol Symbol of the vault.
     * @return _vault Address of the newly created vault.
     */
    function newVault(
        address _asset,
        uint256 _category,
        string calldata _name,
        string calldata _symbol
    ) external returns (address);

    /**
     * @notice Creates a new endorsed vault with default profit max unlock time.
     * @param _asset Address of the underlying asset.
     * @param _category Category of the vault.
     * @param _name Name of the vault.
     * @param _symbol Symbol of the vault.
     * @param _depositLimit The deposit limit to start the vault with.
     * @return _vault Address of the newly created vault.
     */
    function newVault(
        address _asset,
        uint256 _category,
        string calldata _name,
        string calldata _symbol,
        uint256 _depositLimit
    ) external returns (address);

    /**
     * @notice Adds a new vault to the RoleManager with the specified category.
     * @dev If not already endorsed this function will endorse the vault.
     *  A new debt allocator will be deployed and configured.
     * @param _vault Address of the vault to be added.
     * @param _category Category associated with the vault.
     */
    function addNewVault(address _vault, uint256 _category) external;

    /**
     * @notice Adds a new vault to the RoleManager with the specified category and debt allocator.
     * @dev If not already endorsed this function will endorse the vault.
     * @param _vault Address of the vault to be added.
     * @param _category Category associated with the vault.
     * @param _debtAllocator Address of the debt allocator for the vault.
     */
    function addNewVault(
        address _vault,
        uint256 _category,
        address _debtAllocator
    ) external;

    /**
     * @notice Update a `_vault`s debt allocator.
     * @dev This will use the default Debt Allocator currently set.
     * @param _vault Address of the vault to update the allocator for.
     */
    function updateDebtAllocator(
        address _vault
    ) external returns (address _newDebtAllocator);

    /**
     * @notice Update a `_vault`s debt allocator to a specified `_debtAllocator`.
     * @param _vault Address of the vault to update the allocator for.
     * @param _debtAllocator Address of the new debt allocator.
     */
    function updateDebtAllocator(
        address _vault,
        address _debtAllocator
    ) external;

    /**
     * @notice Update a `_vault`s keeper to a specified `_keeper`.
     * @param _vault Address of the vault to update the keeper for.
     * @param _keeper Address of the new keeper.
     */
    function updateKeeper(address _vault, address _keeper) external;

    function updateVaultName(address _vault, string calldata _name) external;

    function updateVaultSymbol(
        address _vault,
        string calldata _symbol
    ) external;

    /**
     * @notice Removes a vault from the RoleManager.
     * @dev This will NOT un-endorse the vault from the registry.
     * @param _vault Address of the vault to be removed.
     */
    function removeVault(address _vault) external;

    /**
     * @notice Removes a specific role(s) for a `_holder` from the `_vaults`.
     * @dev Can be used to remove one specific role or multiple.
     * @param _vaults Array of vaults to adjust.
     * @param _holder Address who's having a role removed.
     * @param _role The role or roles to remove from the `_holder`.
     */
    function removeRoles(
        address[] calldata _vaults,
        address _holder,
        uint256 _role
    ) external;

    // ╭─────────────────────────────────────────────────────────╮
    // │ SETTERS                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /**
     * @notice Setter function for updating a positions roles.
     * @param _position Identifier for the position.
     * @param _newRoles New roles for the position.
     */
    function setPositionRoles(bytes32 _position, uint256 _newRoles) external;

    /**
     * @notice Setter function for updating a positions holder.
     * @dev Updating `Governance` requires setting `PENDING_GOVERNANCE`
     *  and then the pending address calling {acceptGovernance}.
     * @param _position Identifier for the position.
     * @param _newHolder New address for position.
     */
    function setPositionHolder(bytes32 _position, address _newHolder) external;

    /**
     * @notice Sets the default time until profits are fully unlocked for new vaults.
     * @param _newDefaultProfitMaxUnlockTime New value for defaultProfitMaxUnlockTime.
     */
    function setDefaultProfitMaxUnlockTime(
        uint256 _newDefaultProfitMaxUnlockTime
    ) external;

    /**
     * @notice Accept the Governance role.
     * @dev Caller must be the Pending Governance.
     */
    function acceptGovernance() external;

    // ╭─────────────────────────────────────────────────────────╮
    // │ VIEW METHODS                                            │
    // ╰─────────────────────────────────────────────────────────╯

    /**
     * @notice Get the name of this contract.
     */
    function name() external view returns (string memory);

    /**
     * @notice Get all vaults that this role manager controls..
     * @return The full array of vault addresses.
     */
    function getAllVaults() external view returns (address[] memory);

    /**
     * @notice Get the vault for a specific asset, api and category.
     * @dev This will return address(0) if one has not been added or deployed.
     *
     * @param _asset The underlying asset used.
     * @param _apiVersion The version of the vault.
     * @param _category The category of the vault.
     * @return The vault for the specified `_asset`, `_apiVersion` and `_category`.
     */
    function getVault(
        address _asset,
        string memory _apiVersion,
        uint256 _category
    ) external view returns (address);

    /**
     * @notice Get the latest vault for a specific asset.
     * @dev This will default to using category 1.
     * @param _asset The underlying asset used.
     * @return _vault latest vault for the specified `_asset` if any.
     */
    function latestVault(address _asset) external view returns (address);

    /**
     * @notice Get the latest vault for a specific asset.
     * @param _asset The underlying asset used.
     * @param _category The category of the vault.
     * @return _vault latest vault for the specified `_asset` if any.
     */
    function latestVault(
        address _asset,
        uint256 _category
    ) external view returns (address _vault);

    /**
     * @notice Check if a vault is managed by this contract.
     * @dev This will check if the `asset` variable in the struct has been
     *   set for an easy external view check.
     *
     *   Does not check the vaults `role_manager` position since that can be set
     *   by anyone for a random vault.
     *
     * @param _vault Address of the vault to check.
     * @return . The vaults role manager status.
     */
    function isVaultsRoleManager(address _vault) external view returns (bool);

    /**
     * @notice Get the debt allocator for a specific vault.
     * @dev Will return address(0) if the vault is not managed by this contract.
     * @param _vault Address of the vault.
     * @return . Address of the debt allocator if any.
     */
    function getDebtAllocator(address _vault) external view returns (address);

    /**
     * @notice Get the category for a specific vault.
     * @dev Will return 0 if the vault is not managed by this contract.
     * @param _vault Address of the vault.
     * @return . The category of the vault if any.
     */
    function getCategory(address _vault) external view returns (uint256);

    /**
     * @notice Get the address assigned to the Governance position.
     * @return The address assigned to the Governance position.
     */
    function getGovernance() external view returns (address);

    /**
     * @notice Get the address assigned to the Pending Governance position.
     * @return The address assigned to the Pending Governance position.
     */
    function getPendingGovernance() external view returns (address);

    /**
     * @notice Get the address assigned to the Management position.
     * @return The address assigned to the Management position.
     */
    function getManagement() external view returns (address);

    /**
     * @notice Get the address assigned to the Keeper position.
     * @return The address assigned to the Keeper position.
     */
    function getKeeper() external view returns (address);

    /**
     * @notice Get the address assigned to the Registry.
     * @return The address assigned to the Registry.
     */
    function getRegistry() external view returns (address);

    /**
     * @notice Get the address assigned to the accountant.
     * @return The address assigned to the accountant.
     */
    function getAccountant() external view returns (address);

    /**
     * @notice Get the address assigned to be the debt allocator if any.
     * @return The address assigned to be the debt allocator if any.
     */
    function getDebtAllocator() external view returns (address);

    /**
     * @notice Get the roles given to the Governance position.
     * @return The roles given to the Governance position.
     */
    function getGovernanceRoles() external view returns (uint256);

    /**
     * @notice Get the roles given to the Management position.
     * @return The roles given to the Management position.
     */
    function getManagementRoles() external view returns (uint256);

    /**
     * @notice Get the roles given to the Keeper position.
     * @return The roles given to the Keeper position.
     */
    function getKeeperRoles() external view returns (uint256);

    /**
     * @notice Get the roles given to the debt allocators.
     * @return The roles given to the debt allocators.
     */
    function getDebtAllocatorRoles() external view returns (uint256);
}
