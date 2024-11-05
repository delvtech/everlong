// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { Strategy } from "./Strategy.sol";
import { IEverlongStrategy } from "./interfaces/IEverlongStrategy.sol";

contract StrategyFactory {
    event NewStrategy(address indexed strategy, address indexed asset);

    address public immutable emergencyAdmin;

    address public management;
    address public performanceFeeRecipient;
    address public keeper;

    /// @notice Track the deployments. asset => pool => strategy
    mapping(address => address) public deployments;

    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

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
    ) external virtual returns (address) {
        // tokenized strategies available setters.
        IEverlongStrategy _newStrategy = IEverlongStrategy(
            address(new Strategy(_asset, _name, _hyperdrive, _asBase))
        );

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);

        _newStrategy.setKeeper(keeper);

        _newStrategy.setPendingManagement(management);

        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewStrategy(address(_newStrategy), _asset);

        deployments[_asset] = address(_newStrategy);
        return address(_newStrategy);
    }

    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper
    ) external {
        require(msg.sender == management, "!management");
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
    }

    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        address _asset = IEverlongStrategy(_strategy).asset();
        return deployments[_asset] == _strategy;
    }
}
