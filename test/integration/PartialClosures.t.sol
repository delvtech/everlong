// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";

contract PartialClosures is EverlongTest {
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;
    using HyperdriveExecutionLibrary for *;

    /// @dev Tests that immature positions can be partially closed when
    ///      additional liquidity is needed to service a withdrawal.
    ///      Ensures that the amount of longs closed in the position is not
    ///      excessive.
    function testFuzz_partial_closures(
        uint256 _targetIdle,
        uint256 _maxIdle,
        uint256 _deposit,
        uint256 _redemptionPercentage
    ) external {
        TARGET_IDLE_LIQUIDITY_PERCENTAGE = bound(_targetIdle, 0.001e18, 0.5e18);
        MAX_IDLE_LIQUIDITY_PERCENTAGE = bound(
            _maxIdle,
            TARGET_IDLE_LIQUIDITY_PERCENTAGE + 0.001e18,
            0.9e18
        );
        deployEverlong();

        // Alice deposits into Everlong.
        uint256 aliceDepositAmount = bound(
            _deposit,
            MINIMUM_TRANSACTION_AMOUNT * 100,
            hyperdrive.calculateMaxLong()
        );
        uint256 aliceShares = depositEverlong(aliceDepositAmount, alice);
        uint256 positionBondsAfterDeposit = everlong.totalBonds();

        // Alice redeems a significant enough portion of her shares to require
        // partially closing the immature position.
        _redemptionPercentage = bound(
            _redemptionPercentage,
            TARGET_IDLE_LIQUIDITY_PERCENTAGE,
            0.8e18
        );
        uint256 aliceRedeemAmount = aliceShares.mulDown(_redemptionPercentage);
        redeemEverlong(aliceRedeemAmount, alice);
        uint256 positionBondsAfterRedeem = everlong.totalBonds();

        // Ensure Everlong still has a position open.
        assertEq(everlong.positionCount(), 1);

        // Ensure the remaining Everlong position has proportionally less bonds
        // than it did prior to redemption.
        assertApproxEqRel(
            positionBondsAfterDeposit.mulDivDown(
                1e18 - _redemptionPercentage,
                1e18 - TARGET_IDLE_LIQUIDITY_PERCENTAGE
            ),
            positionBondsAfterRedeem,
            0.001e18
        );
    }

    /// @dev Tests the case where a redemption requires closing longs from
    ///      two separate positions that have dramatically different bond prices.
    ///
    ///      If the expected bond prices are calculated using portfolio averages (bad)
    ///      - The output for the least mature bonds will be overestimated
    ///      - The slippage guard will be triggered.
    ///      - The redemption will fail.
    ///
    ///      If the expected bond prices are calculated on a per-position basis (good)
    ///      - The output for all bonds should be correctly estimated.
    ///      - The slippage guard should not be triggered.
    ///      - The redemption will succeed.
    function test_partial_closures_large_position_bond_price_difference()
        external
    {
        TARGET_IDLE_LIQUIDITY_PERCENTAGE = 0.1e18;
        MAX_IDLE_LIQUIDITY_PERCENTAGE = 0.2e18;
        deployEverlong();

        // Alice deposits into Everlong.
        uint256 aliceDepositAmount = 10_000e18;
        uint256 aliceShares = depositEverlong(aliceDepositAmount, alice);

        // Time advances towards the end of the term.
        advanceTimeWithCheckpoints(
            POSITION_DURATION.mulDown(0.9e18),
            VARIABLE_RATE
        );

        // Alice deposits again into Everlong.
        aliceShares += depositEverlong(aliceDepositAmount, alice);

        // Ensure Everlong has two positions and that the bond prices differ
        // by greater than Everlong's max closeLong slippage.
        assertEq(everlong.positionCount(), 2);
        IEverlong.Position memory oldPosition = everlong.positionAt(0);
        IEverlong.Position memory newPosition = everlong.positionAt(1);
        uint256 oldBondPrice = hyperdrive
            .previewCloseLong(true, oldPosition, "")
            .divDown(oldPosition.bondAmount);
        uint256 newBondPrice = hyperdrive
            .previewCloseLong(true, newPosition, "")
            .divDown(newPosition.bondAmount);
        assertGt(
            (oldBondPrice - newBondPrice).divDown(oldBondPrice),
            everlong.maxCloseLongSlippage()
        );

        // Alice redeems enough shares to require closing the first and part
        // of the second position.
        // This should succeed.
        uint256 redeemPercentage = 0.75e18;
        uint256 aliceRedeemAmount = aliceShares.mulDown(redeemPercentage);
        redeemEverlong(aliceRedeemAmount, alice);

        // Ensure Everlong has one position left.
        assertEq(everlong.positionCount(), 1);
    }
}
