// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests the functionality around opening, closing, and valuing hyperdrive positions.
contract TestHyperdriveExecution is EverlongTest {
    using HyperdriveExecutionLibrary for IHyperdrive;
    using FixedPointMath for *;
    using SafeCast for *;
    using Lib for *;

    Portfolio.State public portfolio;

    /// @dev Tests that previewCloseLong returns the correct amount when
    ///      immediately closing a long.
    function test_previewCloseLong_immediate_close() external {
        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            strategy.asBase(),
            hyperdrive.getPoolConfig(),
            IEverlongStrategy.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    /// @dev Tests that previewCloseLong returns the correct amount when
    ///      immediately closing a long with negative interest.
    function test_previewCloseLong_immediate_close_negative_interest()
        external
    {
        // Deploy the vault.instance with a negative interest rate.
        VARIABLE_RATE = -0.05e18;
        super.setUp();

        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            strategy.asBase(),
            hyperdrive.getPoolConfig(),
            IEverlongStrategy.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    /// @dev Tests that previewCloseLong returns the correct amount when
    ///      prematurely closing a long.
    function test_previewCloseLong_partial_maturity() external {
        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpointsAndRebalancing(POSITION_DURATION / 2);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            strategy.asBase(),
            hyperdrive.getPoolConfig(),
            IEverlongStrategy.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    /// @dev Tests that previewCloseLong returns the correct amount when
    ///      prematurely closing a long with negative interest.
    function test_previewCloseLong_partial_maturity_negative_interest()
        external
    {
        // Deploy the vault.instance with a negative interest rate.
        VARIABLE_RATE = -0.05e18;
        super.setUp();

        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpointsAndRebalancing(POSITION_DURATION / 2);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            strategy.asBase(),
            hyperdrive.getPoolConfig(),
            IEverlongStrategy.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    /// @dev Tests that previewCloseLong returns the correct amount when
    ///      closing a long at maturity.
    function test_previewCloseLong_full_maturity() external {
        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpointsAndRebalancing(POSITION_DURATION);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            strategy.asBase(),
            hyperdrive.getPoolConfig(),
            IEverlongStrategy.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    /// @dev Tests that previewCloseLong returns the correct amount when
    ///      closing a long at maturity with negative interest.
    function test_previewCloseLong_full_maturity_negative_interest() external {
        // Deploy the vault.instance.
        VARIABLE_RATE = -0.05e18;
        super.setUp();

        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpoints(POSITION_DURATION, VARIABLE_RATE);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            strategy.asBase(),
            hyperdrive.getPoolConfig(),
            IEverlongStrategy.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    /// @dev Test the output of `calculateMaxLong` when there is a substantial
    ///      long held to an entire term already in hyperdrive.
    function test__calculateMaxLong__matureLong(
        uint256 fixedRate,
        uint256 contribution,
        uint256 matureLongAmount,
        uint256 initialLongAmount,
        uint256 initialShortAmount,
        uint256 finalLongAmount
    ) external {
        // Deploy Hyperdrive.
        fixedRate = fixedRate.normalizeToRange(0.001e18, 0.5e18);
        deploy(alice, fixedRate, 0, 0, 0, 0);

        // Initialize the Hyperdrive pool.
        contribution = contribution.normalizeToRange(1_000e18, 500_000_000e18);
        initialize(alice, fixedRate, contribution);

        // Open a long position that will be held for an entire term. This will
        // decrease the value of the share adjustment to a non-trivial value.
        matureLongAmount = matureLongAmount.normalizeToRange(
            MINIMUM_TRANSACTION_AMOUNT,
            hyperdrive.calculateMaxLong() / 2
        );
        openLong(alice, matureLongAmount);
        advanceTime(hyperdrive.getPoolConfig().positionDuration, 0);

        // Ensure that the max long is actually the max long.
        _verifyMaxLong(
            fixedRate,
            initialLongAmount,
            initialShortAmount,
            finalLongAmount
        );
    }

    /// @dev Test the output of `calculateMaxLong` when there is a substantial
    ///      short held to an entire term already in hyperdrive.
    function test__calculateMaxLong__matureShort(
        uint256 fixedRate,
        uint256 contribution,
        uint256 matureShortAmount,
        uint256 initialLongAmount,
        uint256 initialShortAmount,
        uint256 finalLongAmount
    ) external {
        // Deploy Hyperdrive.
        fixedRate = fixedRate.normalizeToRange(0.001e18, 0.5e18);
        deploy(alice, fixedRate, 0, 0, 0, 0);

        // Initialize the Hyperdrive pool.
        contribution = contribution.normalizeToRange(1_000e18, 500_000_000e18);
        initialize(alice, fixedRate, contribution);

        // Open a short position that will be held for an entire term. This will
        // increase the value of the share adjustment to a non-trivial value.
        matureShortAmount = matureShortAmount.normalizeToRange(
            MINIMUM_TRANSACTION_AMOUNT,
            HyperdriveUtils.calculateMaxShort(hyperdrive) / 2
        );
        openShort(alice, matureShortAmount);
        advanceTime(hyperdrive.getPoolConfig().positionDuration, 0);

        // Ensure that the max long is actually the max long.
        _verifyMaxLong(
            fixedRate,
            initialLongAmount,
            initialShortAmount,
            finalLongAmount
        );
    }

    /// @dev Test specific edge cases for `calculateMaxLong`.
    function test__calculateMaxLong__edgeCases() external {
        // This is an edge case where pool has a spot price of 1 at the optimal
        // trade size but the optimal trade size is less than the value that we
        // solve for when checking the endpoint.
        _test__calculateMaxLong(
            78006570044966433744465072258,
            0,
            0,
            115763819684266577237839082600338781403556286119250692248603493285535482011337,
            0
        );

        // This is an edge case where the present value couldn't be calculated
        // due to a tiny net curve trade.
        _test__calculateMaxLong(
            3988,
            370950184595018764582435593,
            10660,
            999000409571,
            1000000000012659
        );
    }

    /// @dev Broad fuzz testing for `calculateMaxLong`.
    function test__calculateMaxLong__fuzz(
        uint256 fixedRate,
        uint256 contribution,
        uint256 initialLongAmount,
        uint256 initialShortAmount,
        uint256 finalLongAmount
    ) external {
        _test__calculateMaxLong(
            fixedRate,
            contribution,
            initialLongAmount,
            initialShortAmount,
            finalLongAmount
        );
    }

    function _test__calculateMaxLong(
        uint256 fixedRate,
        uint256 contribution,
        uint256 initialLongAmount,
        uint256 initialShortAmount,
        uint256 finalLongAmount
    ) internal {
        // Deploy Hyperdrive.
        fixedRate = fixedRate.normalizeToRange(0.001e18, 0.5e18);
        deploy(alice, fixedRate, 0, 0, 0, 0);

        // Initialize the Hyperdrive pool.
        contribution = contribution.normalizeToRange(1_000e18, 500_000_000e18);
        initialize(alice, fixedRate, contribution);

        // Ensure that the max long is actually the max long.
        _verifyMaxLong(
            fixedRate,
            initialLongAmount,
            initialShortAmount,
            finalLongAmount
        );
    }

    /// @dev Helper to ensure that the output of `calculateMaxLong` is actually
    ///      the max long.
    function _verifyMaxLong(
        uint256 fixedRate,
        uint256 initialLongAmount,
        uint256 initialShortAmount,
        uint256 finalLongAmount
    ) internal {
        // Open a long and a short. This sets the long buffer to a non-trivial
        // value which stress tests the max long function.
        initialLongAmount = initialLongAmount.normalizeToRange(
            MINIMUM_TRANSACTION_AMOUNT,
            hyperdrive.calculateMaxLong() / 2
        );
        openLong(bob, initialLongAmount);
        initialShortAmount = initialShortAmount.normalizeToRange(
            MINIMUM_TRANSACTION_AMOUNT,
            HyperdriveUtils.calculateMaxShort(hyperdrive) / 2
        );
        openShort(bob, initialShortAmount);

        // TODO: The fact that we need such a large amount of iterations could
        // indicate a bug in the max long function.
        //
        // Open the maximum long on Hyperdrive.
        IHyperdrive.PoolConfig memory config = hyperdrive.getPoolConfig();
        IHyperdrive.PoolInfo memory info = hyperdrive.getPoolInfo();
        uint256 maxIterations = 10;
        if (fixedRate > 0.15e18) {
            maxIterations += 5;
        }
        if (fixedRate > 0.35e18) {
            maxIterations += 5;
        }
        (uint256 maxLong, ) = HyperdriveExecutionLibrary.calculateMaxLong(
            HyperdriveExecutionLibrary.MaxTradeParams({
                shareReserves: info.shareReserves,
                shareAdjustment: info.shareAdjustment,
                bondReserves: info.bondReserves,
                longsOutstanding: info.longsOutstanding,
                longExposure: info.longExposure,
                timeStretch: config.timeStretch,
                vaultSharePrice: info.vaultSharePrice,
                initialVaultSharePrice: config.initialVaultSharePrice,
                minimumShareReserves: config.minimumShareReserves,
                curveFee: config.fees.curve,
                flatFee: config.fees.flat,
                governanceLPFee: config.fees.governanceLP
            }),
            hyperdrive.getCheckpointExposure(hyperdrive.latestCheckpoint()),
            maxIterations
        );
        (uint256 maturityTime, uint256 longAmount) = openLong(bob, maxLong);

        // TODO: Re-visit this after fixing `calculateMaxLong` to work with
        // matured positions.
        //
        // Ensure that opening another long fails. We fuzz in the range of
        // 10% to 1000x the max long.
        //
        // NOTE: The max spot price increases after we open the first long
        // because the spot price increases. In some cases, this could cause
        // a small trade to suceed after the large trade, so we use relatively
        // large amounts for the second trade.
        vm.stopPrank();
        vm.startPrank(bob);
        finalLongAmount = finalLongAmount.normalizeToRange(
            maxLong.mulDown(0.1e18).max(MINIMUM_TRANSACTION_AMOUNT),
            maxLong.mulDown(1000e18).max(
                MINIMUM_TRANSACTION_AMOUNT.mulDown(10e18)
            )
        );
        baseToken.mint(bob, finalLongAmount);
        baseToken.approve(address(hyperdrive), finalLongAmount);
        vm.expectRevert();
        hyperdrive.openLong(
            finalLongAmount,
            0,
            0,
            IHyperdrive.Options({
                destination: bob,
                asBase: true,
                extraData: new bytes(0)
            })
        );

        // Ensure that the long can be closed.
        closeLong(bob, maturityTime, longAmount);
    }
}
