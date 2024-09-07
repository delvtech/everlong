// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests the functionality around opening, closing, and valuing hyperdrive positions.
contract TestHyperdriveExecution is EverlongTest {
    using HyperdriveExecutionLibrary for IHyperdrive;
    using SafeCast for *;

    Portfolio.State public portfolio;

    function setUp() public virtual override {
        super.setUp();
        deployEverlong();
    }

    function test_previewOpenLong() external {
        // With no longs, ensure the estimated and actual bond amounts are
        // the same.
        uint256 longAmount = 10e18;
        uint256 previewBonds = hyperdrive.previewOpenLong(
            everlong.asBase(),
            longAmount
        );
        (, uint256 actualBonds) = openLong(alice, longAmount);
        assertEq(previewBonds, actualBonds);

        // Ensure the estimated and actual bond amounts still match when there
        // is an existing position in hyperdrive.
        longAmount = 500e18;
        previewBonds = hyperdrive.previewOpenLong(
            everlong.asBase(),
            longAmount
        );
        (, actualBonds) = openLong(bob, longAmount);
        assertEq(previewBonds, actualBonds);
    }

    function test_previewCloseLong_immediate_close() external {
        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            everlong.asBase(),
            IEverlong.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            })
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    function test_previewCloseLong_partial_maturity() external {
        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpoints(POSITION_DURATION / 2, 0.05e18);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            everlong.asBase(),
            IEverlong.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            })
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    function test_previewCloseLong_portfolio_averages() external {
        // Bob makes the first deposit.
        uint256 bobAmount = 100e18;
        uint256 bobShares = depositEverlong(bobAmount, bob);
        everlong.rebalance();

        // Advance time 1/6th of the way through the term.
        advanceTime(POSITION_DURATION / 6, 0.05e18);

        // Celine makes the second deposit.
        uint256 celineAmount = 100e18;
        uint256 celineShares = depositEverlong(celineAmount, celine);
        everlong.rebalance();

        // Advance time 1/6th of the way through the term.
        advanceTime(POSITION_DURATION / 6, 0.05e18);

        // Dan makes the third deposit.
        uint256 danAmount = 100e18;
        uint256 danShares = depositEverlong(danAmount, dan);
        everlong.rebalance();

        // Advance time 1/6th of the way through the term.
        advanceTime(POSITION_DURATION / 6, 0.05e18);

        // Estimate the portfolio value.
        uint256 estimatedOutput = hyperdrive.previewCloseLong(
            everlong.asBase(),
            IEverlong.Position({
                maturityTime: everlong.avgMaturityTime(),
                bondAmount: everlong.totalBonds()
            })
        );

        // Get the previewRedeem output.
        uint256 redeemOutput = everlong.previewRedeem(
            bobShares + celineShares + danShares
        );
        console.log("redeem output:   %s", redeemOutput);
    }
}
