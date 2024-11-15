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

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 Views                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Gets the Everlong factory's name.
    /// @return The Everlong instance's kind.
    function name() external pure returns (string memory);

    /// @notice Gets the Everlong factory's kind.
    /// @return The Everlong factory's kind.
    function kind() external pure returns (string memory);

    /// @notice Gets the Everlong factory's version.
    /// @return The Everlong factory's version.
    function version() external pure returns (string memory);

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Events                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Emitted when a new EverlongStrategy is created.
    event NewStrategy(address indexed strategy, address indexed asset);
}
