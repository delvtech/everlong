// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @author DELV
/// @title IEverlongStrategyFactory
/// @notice Interface for an EverlongStrategyFactory.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
interface IEverlongStrategyFactory {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                               Stateful                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /**
     * @notice Deploy a new Strategy.
     * @param _asset The underlying asset for the strategy to use.
     * @param _hyperdrive The underlying hyperdrive pool for the strategy to use.
     * @param _asBase Whether to use hyperdrive's base asset.
     * @return . The address of the new strategy.
     */
    function newStrategy(
        address _asset,
        string calldata _name,
        address _hyperdrive,
        bool _asBase
    ) external returns (address);

    /// @notice Update the priviledged addresses that are set for newly-created
    ///         strategies.
    /// @dev Must be called by the current management address.
    /// @param _management New management address.
    /// @param _performanceFeeRecipient New performance fee recipient address.
    /// @param _keeper New keeper address.
    /// @param _emergencyAdmin New emergency admin address.
    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) external;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 Views                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Returns the strategy for the provided asset.
    /// @param _asset Asset to look up a strategy for.
    /// @return strategy Strategy matching the input asset.
    function deployments(
        address _asset
    ) external view returns (address strategy);

    /// @notice The emergency admin address to set for new strategies.
    /// @dev Immutable. Cannot be updated.
    function emergencyAdmin() external view returns (address);

    /// @notice Check whether the strategy was deployed by this factory.
    /// @param _strategy Strategy to evaluate.
    /// @return True if the strategy was deployed by this factory instance,
    ///         false otherwise.
    function isDeployedStrategy(address _strategy) external view returns (bool);

    /// @notice The keeper address to set for new strategies.
    function keeper() external view returns (address);

    /// @notice Gets the Everlong factory's kind.
    /// @return The Everlong factory's kind.
    function kind() external view returns (string memory);

    /// @notice The management address to set for new strategies.
    function management() external view returns (address);

    /// @notice The performance fee recipient address to set for new strategies.
    function performanceFeeRecipient() external view returns (address);

    /// @notice Gets the Everlong factory's name.
    /// @return The Everlong instance's kind.
    function name() external view returns (string memory);

    /// @notice Gets the Everlong factory's version.
    /// @return The Everlong factory's version.
    function version() external view returns (string memory);

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Events                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Emitted when a new EverlongStrategy is created.
    event NewStrategy(address indexed strategy, address indexed asset);

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Errors                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Thrown when attempting to create a strategy for an asset that
    ///         already has a strategy associated with it.
    error ExistingStrategyForAsset();

    /// @notice Thrown when calling a management function as a non-management
    ///         address.
    error OnlyManagement();
}
