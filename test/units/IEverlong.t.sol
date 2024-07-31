// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";

/// @dev Extend only the test harness.
contract IEverlongTest is EverlongTest {
    /// @dev Set up the hyperdrive test from super and deploy Everlong.
    function setUp() public virtual override {
        super.setUp();
        deploy();
    }

    /// @dev Ensure that the `hyperdrive()` view function is implemented.
    function test_hyperdrive() external view {
        assertEq(
            everlong.hyperdrive(),
            address(hyperdrive),
            "hyperdrive() should return hyperdrive address"
        );
    }

    /// @dev Ensure that the `asset()` view function is implemented.
    function test_asset() external view {
        assertEq(
            everlong.asset(),
            address(hyperdrive.baseToken()),
            "asset() should return hyperdrive base token address"
        );
    }

    /// @dev Ensure that the `name()` view function is implemented.
    function test_name() external view {
        assertNotEq(everlong.name(), "", "name() not return an empty string");
    }

    /// @dev Ensure that the `symbol()` view function is implemented.
    function test_symbol() external view {
        assertNotEq(
            everlong.symbol(),
            "",
            "symbol() not return an empty string"
        );
    }

    /// @dev Ensure that the `kind()` view function is implemented.
    function test_kind() external view {
        assertNotEq(everlong.kind(), "", "kind is empty string");
    }

    /// @dev Ensure that the `version()` view function is implemented.
    function test_version() external view {
        assertNotEq(everlong.version(), "", "version is empty string");
    }

    /// @dev Ensure that `canRebalance()` returns false when everlong has
    ///      no positions nor balance.
    function test_canRebalance_false_no_positions_no_balance() external {
        // Check that Everlong:
        // - has no positions
        // - has no balance
        // - `canRebalance()` returns false
        assertEq(
            everlong.getPositionCount(),
            0,
            "everlong should not intialize with positions"
        );
        assertEq(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            0,
            "everlong should not initialize with a balance"
        );
        assertFalse(
            everlong.canRebalance(),
            "cannot rebalance without matured positions or balance"
        );
    }

    /// @dev Ensures that `canRebalance()` only returns true with a balance
    ///      greater than or equal to Hyperdrive's minTransactionAmount or
    ///      with matured positions.
    /// @dev The test goes through the following steps:
    ///         1. Mint `asset` to the Everlong contract and approve Hyperdrive.
    ///            - `canRebalance()` should return true with a balance.
    ///         2. Call `rebalance()` to open a position with all of balance.
    ///            - `canRebalance()` should return false with no balance.
    ///         3. Increase block.timestamp until the position is mature.
    ///            - `canRebalance()` should return true with a mature position.
    ///         4. Call `rebalance()` again to close matured positions
    ///            and use proceeds to open new position.
    ///         5. `canRebalance()` should return false with no matured positions
    ///            and no balance.
    function test_canRebalance_with_balance_matured_positions() external {
        // Initialize the Hyperdrive instance by adding liquidity from Alice.
        uint256 fixedRate = 0.5e18;
        uint256 contribution = 10_000e18;
        uint256 lpShares = initialize(alice, fixedRate, contribution);

        // 1. Mint some tokens to Everlong for opening Longs.
        // Ensure Everlong's balance is gte Hyperdrive's minTransactionAmount.
        // Ensure `canRebalance()` returns true.
        mintApproveHyperdriveBase(address(everlong), 100e18);
        assertGe(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            hyperdrive.getPoolConfig().minimumTransactionAmount
        );
        assertTrue(
            everlong.canRebalance(),
            "everlong should be able to rebalance when it has a balance > hyperdrive's minTransactionAmount"
        );

        // 2. Call `rebalance()` to cause Everlong to open a position.
        // Ensure the `Rebalanced()` event is emitted.
        // Ensure the position count is now 1.
        // Ensure Everlong's balance is lt Hyperdrive's minTransactionAmount.
        // Ensure `canRebalance()` returns false.
        vm.expectEmit(true, true, true, true);
        emit Rebalanced();
        everlong.rebalance();
        assertEq(
            everlong.getPositionCount(),
            1,
            "position count after first rebalance with balance should be 1"
        );
        assertLt(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            hyperdrive.getPoolConfig().minimumTransactionAmount,
            "everlong balance after first rebalance should be less than hyperdrive's minTransactionAmount"
        );
        assertFalse(
            everlong.canRebalance(),
            "cannot rebalance without matured positions nor sufficient balance after first rebalance"
        );

        // 3. Increase block.timestamp until position is mature.
        // Ensure Everlong has a matured position.
        // Ensure `canRebalance()` returns true.
        vm.warp(everlong.getPosition(0).maturityTime);
        assertTrue(
            everlong.hasMaturedPositions(),
            "everlong should have matured position after calling warp"
        );
        assertTrue(
            everlong.canRebalance(),
            "everlong should allow rebalance with matured position"
        );

        // 4. Call `rebalance()` to close mature position
        // and open new position with proceeds.
        // Ensure position count remains 1.
        // Ensure Everlong does not have matured positions.
        // Ensure Everlong does not have a balance > minTransactionAmount.
        // Ensure `canRebalance()` returns false.
        everlong.rebalance();
        assertEq(
            everlong.getPositionCount(),
            1,
            "position count after second rebalance with matured position should be 1"
        );
        assertFalse(
            everlong.hasMaturedPositions(),
            "everlong should not have matured position after second rebalance"
        );
        assertLt(
            IERC20(everlong.asset()).balanceOf(address(everlong)),
            hyperdrive.getPoolConfig().minimumTransactionAmount,
            "everlong balance after second rebalance should be less than hyperdrive's minTransactionAmount"
        );
        assertFalse(
            everlong.canRebalance(),
            "cannot rebalance without matured positions nor sufficient balance after second rebalance"
        );
    }
}
