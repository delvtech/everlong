// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { IERC20 } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";

/// @dev Test idle liquidity maintenance for the vault.
contract TestIdle is EverlongTest {
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;
    using HyperdriveExecutionLibrary for *;

    /// @dev Assert that the vault's current idle liquidity is equal to
    ///      the minimum.
    /// @param _msg Error message displayed if assertion fails.
    function assertIdleEqMin(string memory _msg) internal view {
        assertEq(
            vault.totalIdle().divDown(vault.totalDebt() + vault.totalIdle()),
            MIN_IDLE_LIQUIDITY_BASIS_POINTS.divDown(10_000),
            _msg
        );
    }

    /// @dev Assert that the vault's current idle liquidity is greater than the
    ///      minimum.
    /// @param _msg Error message displayed if assertion fails.
    function assertIdleGtMin(string memory _msg) internal view {
        assertGt(
            vault.totalIdle().divDown(vault.totalDebt() + vault.totalIdle()),
            MIN_IDLE_LIQUIDITY_BASIS_POINTS.divDown(10_000),
            _msg
        );
    }

    /// @dev Assert that the vault's current idle liquidity is equal to
    ///      the target.
    /// @param _msg Error message displayed if assertion fails.
    function assertIdleEqTarget(string memory _msg) internal view {
        assertEq(
            vault.totalIdle().divDown(vault.totalDebt() + vault.totalIdle()),
            TARGET_IDLE_LIQUIDITY_BASIS_POINTS.divDown(10_000),
            _msg
        );
    }

    /// @dev Assert that the vault's current idle liquidity is less than the
    ///      target.
    /// @param _msg Error message displayed if assertion fails.
    function assertIdleLtTarget(string memory _msg) internal view {
        assertLt(
            vault.totalIdle().divDown(vault.totalDebt() + vault.totalIdle()),
            TARGET_IDLE_LIQUIDITY_BASIS_POINTS.divDown(10_000),
            _msg
        );
    }

    /// @dev Test idle liquidity after a series of deposits and redemptions.
    ///
    ///      Expected Behavior:
    ///      - If the deposit WOULD cause idle to exceed the target, update debt
    ///        and leave the target idle in the vault.
    ///      - If the deposit WOULD NOT cause idle to exceed the target, do not
    ///        update debt and leave idle between min and target.
    ///      - If the redemption WOULD cause idle to go beneath the min, free
    ///        sufficient assets to leave the target idle.
    ///      - If the redemption WOULD NOT cause idle to go beneath the min,
    ///        do not update debt.
    ///
    ///      Test Flow:
    ///      1. Large Deposit: Idle == MIN
    ///      2. Small Deposit: Idle > MIN
    ///      3. Medium Deposit: Idle == MIN
    ///      4. Medium Redeem: Idle == TARGET
    ///      5. Small Redeem: MIN < Idle < TARGET
    ///      6. Large Redeem: Idle == 0
    function test_idle() external {
        uint256 bigDepositAmount = 20_000e18;
        uint256 mediumDepositAmount = 15_000e18;
        uint256 smallDepositAmount = 50e18;

        // Idle after big deposit should equal min.
        uint256 bigDepositShares = depositVault(bigDepositAmount, alice, true);
        assertIdleEqMin("after big deposit");

        // Idle after small deposit should be greater than min.
        uint256 smallDepositShares = depositVault(
            smallDepositAmount,
            alice,
            true
        );
        assertIdleGtMin("after small deposit");

        // Idle after medium deposit should equal min.
        uint256 mediumDepositShares = depositVault(
            mediumDepositAmount,
            alice,
            true
        );
        assertIdleEqMin("after medium deposit");

        // Idle after medium redeem should equal target.
        redeemVault(mediumDepositShares, alice, true);
        assertIdleEqTarget("after medium redeem");

        // Idle after small redeem should be below target.
        redeemVault(smallDepositShares, alice, true);
        assertIdleLtTarget("after small redeem");

        // Idle after big redeem should be zero.
        redeemVault(bigDepositShares, alice, true);
        assertEq(vault.totalIdle(), 0, "after big redeem");
    }
}
