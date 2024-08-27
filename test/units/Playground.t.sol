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

/// @dev Tests Playground functionality.
contract Playground is EverlongTest {
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

    function half_term(
        uint256 initialVaultSharePrice,
        int256 preTradeVariableInterest,
        int256 variableInterest
    ) internal {
        // Initialize the market
        uint256 apr = 0.05e18;
        deploy(alice, apr, initialVaultSharePrice, 0, 0, 0, 0);
        uint256 contribution = 500_000_000e18;
        initialize(alice, apr, contribution);

        // fast forward time and accrue negative interest
        advanceTime(POSITION_DURATION, preTradeVariableInterest);
        IHyperdrive.PoolInfo memory poolInfo = hyperdrive.getPoolInfo();
        uint256 openVaultSharePrice = poolInfo.vaultSharePrice;

        // Open a long position.
        uint256 basePaid = 10_000e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(bob, basePaid);

        // half term passes
        advanceTime(POSITION_DURATION / 2, variableInterest);

        // Estimate the proceeds.
        poolInfo = hyperdrive.getPoolInfo();
        uint256 closeVaultSharePrice = poolInfo.vaultSharePrice;
        uint256 estimatedProceeds = estimateLongProceeds(
            bondAmount,
            HyperdriveUtils.calculateTimeRemaining(hyperdrive, maturityTime),
            openVaultSharePrice,
            closeVaultSharePrice
        );

        // Close the long.
        uint256 baseProceeds = closeLong(bob, maturityTime, bondAmount);
        assertApproxEqAbs(baseProceeds, estimatedProceeds, 20);
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
        IHyperdrive.PoolInfo memory poolInfo = hyperdrive.getPoolInfo();

        vm.startPrank(bob);

        // Deposit.
        uint256 basePaid = 10e18;
        ERC20Mintable(everlong.asset()).mint(basePaid);
        ERC20Mintable(everlong.asset()).approve(address(everlong), basePaid);
        uint256 shares = everlong.deposit(basePaid, bob);
        console.log("shares: %s", shares);
        everlong.rebalance();

        console.log("avg maturity: %s", everlong.avgMaturity());
        console.log("quantity: %s", everlong.quantity());
        console.log("avg vsp: %s", everlong.avgVaultSharePrice());

        // half term passes
        advanceTime(POSITION_DURATION / 2, variableInterest);

        // Estimate the proceeds.
        uint256 estimatedProceeds = everlong.previewRedeem(shares);

        // Close the long.
        uint256 baseProceeds = everlong.redeem(shares, bob, bob);

        console.log("total assets after: %s", baseProceeds);
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
