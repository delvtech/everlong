// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { Packing } from "openzeppelin/utils/Packing.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

uint256 constant HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT = 2;
uint256 constant HYPERDRIVE_LONG_EXPOSURE_LONGS_OUTSTANDING_SLOT = 3;
uint256 constant HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT = 4;

/// @dev Tests pricing functionality for the portfolio and unmatured positions.
contract TestCloseImmatureLongs is EverlongTest {
    using Packing for bytes32;
    using FixedPointMath for uint128;
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;

    function test_positive_interest_long_half_term_fees() external {
        // This tests the following scenario:
        // - initial_vault_share_price > 1
        // - positive interest causes the share price to go up
        // - a long is opened
        // - positive interest accrues over half term
        // - long is closed
        {
            uint256 initialVaultSharePrice = 1.5e18;
            int256 preTradeVariableInterest = 0.10e18;
            int256 variableInterest = 0.05e18;
            half_term_everlong_fees(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }

        // This tests the following scenario:
        // - initial_vault_share_price = 1
        // - positive interest causes the share price to go up
        // - a long is opened
        // - positive interest accrues over half term
        // - long is closed
        {
            uint256 initialVaultSharePrice = 1e18;
            int256 preTradeVariableInterest = 0.10e18;
            int256 variableInterest = 0.05e18;
            half_term_everlong_fees(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }

        // This tests the following scenario:
        // - initial_vault_share_price < 1
        // - positive interest causes the share price to go up
        // - a long is opened
        // - positive interest accrues over half term
        // - long is closed
        {
            uint256 initialVaultSharePrice = 0.95e18;
            int256 preTradeVariableInterest = 0.10e18;
            int256 variableInterest = 0.05e18;
            half_term_everlong_fees(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }
    }

    function test_negative_interest_long_half_term_fees() external {
        // This tests the following scenario:
        // - initial_vault_share_price > 1
        // - negative interest causes the share price to go down
        // - a long is opened
        // - negative interest accrues over half term
        // - long is closed
        {
            uint256 initialVaultSharePrice = 1.5e18;
            int256 preTradeVariableInterest = -0.10e18;
            int256 variableInterest = -0.05e18;
            half_term_everlong_fees(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }

        // This tests the following scenario:
        // - initial_vault_share_price = 1
        // - negative interest causes the share price to go down
        // - a long is opened
        // - negative interest accrues over half term
        // - long is closed
        {
            uint256 initialVaultSharePrice = 1e18;
            int256 preTradeVariableInterest = -0.10e18;
            int256 variableInterest = -0.05e18;
            half_term_everlong_fees(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }

        // This tests the following scenario:
        // - initial_vault_share_price < 1
        // - negative interest causes the share price to go further down
        // - a long is opened
        // - negative interest accrues over half term
        // - long is closed
        {
            uint256 initialVaultSharePrice = 0.90e18;
            int256 preTradeVariableInterest = -0.10e18;
            int256 variableInterest = -0.05e18;
            half_term_everlong_fees(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }
    }

    function half_term_everlong_fees(
        uint256 initialVaultSharePrice,
        int256 preTradeVariableInterest,
        int256 variableInterest
    ) internal {
        INITIAL_VAULT_SHARE_PRICE = initialVaultSharePrice;
        VARIABLE_RATE = preTradeVariableInterest;
        VARIABLE_RATE = variableInterest;

        vm.startPrank(bob);

        // Deposit.
        uint256 basePaid = 10_000e18;
        ERC20Mintable(strategy.asset()).mint(basePaid);
        ERC20Mintable(strategy.asset()).approve(address(vault), basePaid);
        uint256 shares = depositStrategy(basePaid, bob, true);

        // half term passes
        advanceTimeWithCheckpointsAndRebalancing(POSITION_DURATION / 2);

        // Create a report to update the strategy's `totalAssets`.
        report();

        // Estimate the proceeds.
        uint256 estimatedProceeds = strategy.previewRedeem(shares);

        // Close the long.
        uint256 baseProceeds = redeemStrategy(shares, bob, true);

        assertGe(baseProceeds, estimatedProceeds);
        assertApproxEqAbs(
            baseProceeds,
            estimatedProceeds,
            20,
            "failed equality"
        );
        vm.stopPrank();
    }
}
