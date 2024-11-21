// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { IEverlongStrategyFactory } from "../../contracts/interfaces/IEverlongStrategyFactory.sol";
import { EverlongStrategyFactory } from "../../contracts/EverlongStrategyFactory.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";

contract TestEverlongStrategyFactory is EverlongTest {
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;
    using HyperdriveExecutionLibrary for *;

    /// @dev Tests that setAddresses succeeds when called by management.
    function test_setAddresses_success() external {
        // Generate some addresses.
        address management = createUser("management1");
        address performanceFeeRecipient = createUser(
            "performanceFeeRecipient1"
        );
        address keeper = createUser("keeper1");
        address emergencyAdmin = createUser("emergencyAdmin1");

        // Call setAddresses as the management with new addresses.
        vm.prank(strategyFactory.management());
        strategyFactory.setAddresses(
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );

        // Ensure the addresses are set in the factory's storage.
        assertEq(management, strategyFactory.management());
        assertEq(
            performanceFeeRecipient,
            strategyFactory.performanceFeeRecipient()
        );
        assertEq(keeper, strategyFactory.keeper());
        assertEq(emergencyAdmin, strategyFactory.emergencyAdmin());
    }

    /// @dev Tests that setAddresses fails when not called by management.
    function test_setAddresses_failure_OnlyManagement() external {
        // Generate some addresses.
        address management = createUser("management1");
        address performanceFeeRecipient = createUser(
            "performanceFeeRecipient1"
        );
        address keeper = createUser("keeper1");
        address emergencyAdmin = createUser("emergencyAdmin1");

        // Call setAddresses as a non-management.
        // The call should revert with 'OnlyManagement'.
        vm.startPrank(address(1));
        vm.expectRevert(IEverlongStrategyFactory.OnlyManagement.selector);
        strategyFactory.setAddresses(
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );
        vm.stopPrank();
    }

    /// @dev Tests that factory-created strategies have the correct storage
    ///      variables set.
    function test_newStrategy_success() external {
        address _asset = address(
            new ERC20Mintable(
                "Test",
                "TEST",
                18,
                address(0),
                false,
                type(uint256).max
            )
        );
        string memory _name = "TestEverlongStrategy";
        bool asBase = true;

        IEverlongStrategy newStrategy = IEverlongStrategy(
            strategyFactory.newStrategy(
                _asset,
                _name,
                address(hyperdrive),
                asBase
            )
        );

        // Check that storage has the correct values.
        assertEq(_name, newStrategy.name());
        assertEq(_asset, newStrategy.asset());
        assertEq(asBase, newStrategy.asBase());
        assertEq(address(hyperdrive), newStrategy.hyperdrive());
        assertEq(strategyFactory.management(), newStrategy.pendingManagement());
        assertEq(
            strategyFactory.performanceFeeRecipient(),
            newStrategy.performanceFeeRecipient()
        );
        assertEq(strategyFactory.keeper(), newStrategy.keeper());
        assertEq(
            strategyFactory.emergencyAdmin(),
            newStrategy.emergencyAdmin()
        );

        // Check that the factory can identify creation of the strategy.
        assertTrue(strategyFactory.isDeployedStrategy(address(newStrategy)));
    }

    /// @dev Tests that calling newStrategy fails when the factory has already
    ///      deployed a strategy for the specified asset.
    function test_newStrategy_failure_ExistingStrategyForAsset() external {
        string memory _name = "TestEverlongStrategy";
        bool asBase = true;
        address existingAsset = address(strategy.asset());

        vm.expectRevert(
            IEverlongStrategyFactory.ExistingStrategyForAsset.selector
        );
        strategyFactory.newStrategy(
            existingAsset,
            _name,
            address(hyperdrive),
            asBase
        );
    }

    /// @dev Tests that isDeployedStrategy returns false when it hasn't created
    //       the strategy.
    function test_isDeployedStrategy_failure() external {
        // Generate some addresses.
        string memory name = "TestingEverlongStrategyFactory";
        address management = createUser("management");
        address performanceFeeRecipient = createUser("performanceFeeRecipient");
        address keeper = createUser("keeper");
        address emergencyAdmin = createUser("emergencyAdmin");

        // Deploy the factory.
        strategyFactory = new EverlongStrategyFactory(
            name,
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );

        // Ensure the addresses are set in the factory's storage.
        assertFalse(strategyFactory.isDeployedStrategy(address(strategy)));
    }

    /// @dev Tests that the constructor sets storage variables.
    function test_constructor_success() external {
        // Generate some addresses.
        string memory name = "TestingEverlongStrategyFactory";
        address management = createUser("management");
        address performanceFeeRecipient = createUser("performanceFeeRecipient");
        address keeper = createUser("keeper");
        address emergencyAdmin = createUser("emergencyAdmin");

        // Deploy the factory.
        strategyFactory = new EverlongStrategyFactory(
            name,
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );

        // Ensure the addresses are set in the factory's storage.
        assertEq(name, strategyFactory.name());
        assertEq(management, strategyFactory.management());
        assertEq(
            performanceFeeRecipient,
            strategyFactory.performanceFeeRecipient()
        );
        assertEq(keeper, strategyFactory.keeper());
        assertEq(emergencyAdmin, strategyFactory.emergencyAdmin());
    }
}
