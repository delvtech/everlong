// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

contract PartialClosures is EverlongTest {
    using Lib for *;
    using HyperdriveUtils for *;

    function test_partial_closures_no_idle() external {
        TARGET_IDLE_LIQUIDITY_PERCENTAGE = 0;
        MAX_IDLE_LIQUIDITY_PERCENTAGE = 0;
        super.setUp();
        deployEverlong();

        // Alice deposits into Everlong.
        uint256 aliceDepositAmount = 10_000e18;
        uint256 aliceShares = depositEverlong(aliceDepositAmount, alice);
        uint256 positionBondsAfterDeposit = everlong.totalBonds();

        // Alice redeems a portion of her shares.
        uint256 aliceRedeemDivisor = 2;
        uint256 aliceRedeemAmount = aliceShares / aliceRedeemDivisor;
        redeemEverlong(aliceRedeemAmount, alice);
        uint256 positionBondsAfterRedeem = everlong.totalBonds();

        // Ensure Everlong still has a position open.
        assertEq(everlong.positionCount(), 1);

        // Ensure the remaining Everlong position has proportionally less bonds
        // than it did prior to redemption.
        assertApproxEqRel(
            positionBondsAfterDeposit / aliceRedeemDivisor,
            positionBondsAfterRedeem,
            0.001e18
        );
    }

    function test_partial_closures_idle() external {
        TARGET_IDLE_LIQUIDITY_PERCENTAGE = 0.1e18;
        MAX_IDLE_LIQUIDITY_PERCENTAGE = 0.2e18;
        super.setUp();
        deployEverlong();

        // Alice deposits into Everlong.
        uint256 aliceDepositAmount = 10_000e18;
        uint256 aliceShares = depositEverlong(aliceDepositAmount, alice);
        uint256 positionBondsAfterDeposit = everlong.totalBonds();

        // Alice redeems a portion of her shares.
        uint256 aliceRedeemDivisor = 2;
        uint256 aliceRedeemAmount = aliceShares / aliceRedeemDivisor;
        redeemEverlong(aliceRedeemAmount, alice);
        uint256 positionBondsAfterRedeem = everlong.totalBonds();

        // Ensure Everlong still has a position open.
        assertEq(everlong.positionCount(), 1);

        // Ensure the remaining Everlong position has proportionally less bonds
        // than it did prior to redemption.
        assertApproxEqRel(
            positionBondsAfterDeposit / aliceRedeemDivisor,
            positionBondsAfterRedeem,
            0.001e18
        );
    }
}
