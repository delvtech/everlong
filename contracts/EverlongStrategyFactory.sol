// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IEverlongStrategyFactory } from "./interfaces/IEverlongStrategyFactory.sol";
import { IEverlongStrategy } from "./interfaces/IEverlongStrategy.sol";
import { EVERLONG_STRATEGY_FACTORY_KIND, EVERLONG_VERSION } from "./libraries/Constants.sol";
import { EverlongStrategy } from "./EverlongStrategy.sol";

// TODO: Add testing.
//
/// @author DELV
/// @title EverlongStrategyFactory
/// @notice A factory for creating EverlongStrategy instances.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract EverlongStrategyFactory is IEverlongStrategyFactory {
    /// @inheritdoc IEverlongStrategyFactory
    string public name;

    /// @inheritdoc IEverlongStrategyFactory
    string public constant kind = EVERLONG_STRATEGY_FACTORY_KIND;

    /// @inheritdoc IEverlongStrategyFactory
    string public constant version = EVERLONG_VERSION;

    /// @inheritdoc IEverlongStrategyFactory
    address public immutable emergencyAdmin;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 State                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongStrategyFactory
    address public management;

    /// @inheritdoc IEverlongStrategyFactory
    address public performanceFeeRecipient;

    /// @inheritdoc IEverlongStrategyFactory
    address public keeper;

    /// @inheritdoc IEverlongStrategyFactory
    mapping(address => address) public deployments;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              Constructor                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    constructor(
        string memory _name,
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) {
        name = _name;
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                               Stateful                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongStrategyFactory
    function newStrategy(
        address _asset,
        string calldata _name,
        address _hyperdrive,
        bool _asBase
    ) external virtual returns (address) {
        // Ensure that the new strategy would not overwrite an existing strategy
        // deployed by this factory.
        if (deployments[_asset] != address(0)) {
            revert ExistingStrategyForAsset();
        }

        // Create the strategy and set the priviledged addresses.
        IEverlongStrategy _newStrategy = IEverlongStrategy(
            address(new EverlongStrategy(_asset, _name, _hyperdrive, _asBase))
        );
        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        _newStrategy.setKeeper(keeper);
        _newStrategy.setPendingManagement(management);
        _newStrategy.setEmergencyAdmin(emergencyAdmin);
        emit NewStrategy(address(_newStrategy), _asset);

        // Store the strategy's address.
        deployments[_asset] = address(_newStrategy);
        return address(_newStrategy);
    }

    /// @inheritdoc IEverlongStrategyFactory
    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper
    ) external {
        // Only the management address can set addresses.
        if (msg.sender != management) {
            revert OnlyManagement();
        }

        // Update the addresses.
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 Views                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongStrategyFactory
    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        address _asset = IEverlongStrategy(_strategy).asset();
        return deployments[_asset] == _strategy;
    }
}
