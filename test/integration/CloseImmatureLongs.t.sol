// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { Packing } from "openzeppelin/utils/Packing.sol";

uint256 constant HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT = 2;
uint256 constant HYPERDRIVE_LONG_EXPOSURE_LONGS_OUTSTANDING_SLOT = 3;
uint256 constant HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT = 4;

/// @dev Tests pricing functionality for the portfolio and unmatured positions.
contract CloseImmatureLongs is EverlongTest {
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
        deployEverlong();
        VARIABLE_RATE = variableInterest;

        vm.startPrank(bob);

        // Deposit.
        uint256 basePaid = 10_000e18;
        ERC20Mintable(everlong.asset()).mint(basePaid);
        ERC20Mintable(everlong.asset()).approve(address(everlong), basePaid);
        uint256 shares = depositEverlong(basePaid, bob, true);

        // half term passes
        advanceTimeWithCheckpointsAndRebalancing(POSITION_DURATION / 2);

        // Estimate the proceeds.
        uint256 estimatedProceeds = everlong.previewRedeem(shares);
        console.log("previewRedeem: %e", estimatedProceeds);
        console.log("totalAssets:   %e", everlong.totalAssets());

        // Close the long.
        uint256 baseProceeds = redeemEverlong(shares, bob, true);
        console.log("actual:    %s", baseProceeds);
        console.log(
            "assets:    %s",
            ERC20Mintable(everlong.asset()).balanceOf(address(everlong))
        );
        console.log("avg maturity time: %s", everlong.avgMaturityTime());
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

    /// @dev Tests the situation where the closing of an immature position
    ///      results in losses that exceed the amount of assets owed to the
    ///      redeemer who forced the position closure.
    function testFuzz_immature_losses_exceed_assets_owed(
        uint256 _depositAmount,
        uint256 _shareAmount
    ) external {
        // Deploy Everlong.
        deployEverlong();

        // Make a large deposit.
        _depositAmount = bound(
            _depositAmount,
            hyperdrive.calculateMaxLong() / 100,
            hyperdrive.calculateMaxLong() / 3
        );

        // Ensure previewRedeem returns zero for a small amount of shares.
        depositEverlong(_depositAmount, bob, true);
        _shareAmount = bound(_shareAmount, 0, 1000);
        uint256 assetsOwed = everlong.previewRedeem(_shareAmount);
        assertEq(assetsOwed, 0);

        // Ensure revert when attempting to redeem a small amount of shares.
        vm.expectRevert(IEverlong.RedemptionZeroOutput.selector);
        redeemEverlong(_shareAmount, bob, true);
    }
}
