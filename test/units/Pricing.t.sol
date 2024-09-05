// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { EVERLONG_KIND, EVERLONG_VERSION } from "../../contracts/libraries/Constants.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { Packing } from "openzeppelin/utils/Packing.sol";

uint256 constant HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT = 2;
uint256 constant HYPERDRIVE_LONG_EXPOSURE_LONGS_OUTSTANDING_SLOT = 3;
uint256 constant HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT = 4;

/// @dev Tests pricing functionality for the portfolio and unmatured positions.
contract PricingTest is EverlongTest {
    using Packing for bytes32;
    using FixedPointMath for uint128;
    using FixedPointMath for uint256;
    using Lib for *;

    function test_positive_interest_long_half_term() external {
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
            half_term_everlong(
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
            half_term_everlong(
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
            half_term_everlong(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }
    }

    function test_negative_interest_long_half_term() external {
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
            half_term_everlong(
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
            half_term_everlong(
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
            half_term_everlong(
                initialVaultSharePrice,
                preTradeVariableInterest,
                variableInterest
            );
        }
    }

    function half_term_everlong(
        uint256 initialVaultSharePrice,
        int256 preTradeVariableInterest,
        int256 variableInterest
    ) internal {
        // Initialize the market
        uint256 apr = 0.05e18;
        deploy(alice, apr, initialVaultSharePrice, 0, 0, 0, 0);
        uint256 contribution = 500_000_000e18;
        initialize(alice, apr, contribution);
        vm.startPrank(deployer);
        deploy();
        vm.stopPrank();

        // fast forward time and accrue negative interest
        advanceTime(POSITION_DURATION, preTradeVariableInterest);

        vm.startPrank(bob);

        // Deposit.
        uint256 basePaid = 10_000e18;
        ERC20Mintable(everlong.asset()).mint(basePaid);
        ERC20Mintable(everlong.asset()).approve(address(everlong), basePaid);
        uint256 shares = everlong.deposit(basePaid, bob);
        everlong.rebalance();

        // half term passes
        advanceTime(POSITION_DURATION / 2, variableInterest);

        // Estimate the proceeds.
        uint256 estimatedProceeds = everlong.previewRedeem(shares);
        console.log("previewRedeem: %s", estimatedProceeds);
        console.log("totalAssets:   %s", everlong.totalAssets());

        // Close the long.
        uint256 baseProceeds = everlong.redeem(shares, bob, bob);
        console.log("actual:    %s", baseProceeds);
        console.log(
            "assets:    %s",
            ERC20Mintable(everlong.asset()).balanceOf(address(everlong))
        );
        console.log("avg maturity time: %s", everlong.avgMaturityTime());
        console.log("avg price        : %s", everlong.avgVaultSharePrice());
        console.log("total bonds      : %s", everlong.totalBonds());
        if (estimatedProceeds > baseProceeds) {
            console.log("DIFFERENCE: %s", estimatedProceeds - baseProceeds);
        }

        // logPortfolioMetrics();

        assertGe(baseProceeds, estimatedProceeds);
        assertApproxEqAbs(
            baseProceeds,
            estimatedProceeds,
            20,
            "failed equality"
        );
        vm.stopPrank();
    }

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
        // Initialize the market
        uint256 apr = 0.05e18;
        deploy(
            alice,
            apr,
            initialVaultSharePrice,
            0.01e18,
            0.0005e18,
            0.15e18,
            0.03e18
        );
        uint256 contribution = 500_000_000e18;
        initialize(alice, apr, contribution);
        vm.startPrank(deployer);
        deploy();
        vm.stopPrank();

        // fast forward time and accrue negative interest
        advanceTime(POSITION_DURATION, preTradeVariableInterest);

        vm.startPrank(bob);

        // Deposit.
        uint256 basePaid = 10_000e18;
        ERC20Mintable(everlong.asset()).mint(basePaid);
        ERC20Mintable(everlong.asset()).approve(address(everlong), basePaid);
        uint256 shares = everlong.deposit(basePaid, bob);
        everlong.rebalance();

        // half term passes
        advanceTime(POSITION_DURATION / 2, variableInterest);

        // Estimate the proceeds.
        uint256 estimatedProceeds = everlong.previewRedeem(shares);
        console.log("previewRedeem: %s", estimatedProceeds);
        console.log("totalAssets:   %s", everlong.totalAssets());

        // Close the long.
        uint256 baseProceeds = everlong.redeem(shares, bob, bob);
        console.log("actual:    %s", baseProceeds);
        console.log(
            "assets:    %s",
            ERC20Mintable(everlong.asset()).balanceOf(address(everlong))
        );
        console.log("avg maturity time: %s", everlong.avgMaturityTime());
        console.log("avg price        : %s", everlong.avgVaultSharePrice());
        console.log("total bonds      : %s", everlong.totalBonds());
        if (estimatedProceeds > baseProceeds) {
            console.log("DIFFERENCE: %s", estimatedProceeds - baseProceeds);
        }

        // logPortfolioMetrics();

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
