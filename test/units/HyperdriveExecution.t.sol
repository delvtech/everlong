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
    }

    function test_previewOpenLong() external {
        // Deploy the everlong instance.
        deployEverlong();

        // With no longs, ensure the estimated and actual bond amounts are
        // the same.
        uint256 longAmount = 10e18;
        uint256 previewBonds = hyperdrive.previewOpenLong(
            everlong.asBase(),
            longAmount,
            ""
        );
        (, uint256 actualBonds) = openLong(alice, longAmount);
        assertEq(previewBonds, actualBonds);

        // Ensure the estimated and actual bond amounts still match when there
        // is an existing position in hyperdrive.
        longAmount = 500e18;
        previewBonds = hyperdrive.previewOpenLong(
            everlong.asBase(),
            longAmount,
            ""
        );
        (, actualBonds) = openLong(bob, longAmount);
        assertEq(previewBonds, actualBonds);
    }

    function test_previewCloseLong_immediate_close() external {
        // Deploy the everlong instance.
        deployEverlong();

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
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    function test_previewCloseLong_immediate_close_negative_interest()
        external
    {
        // Deploy the everlong instance with a negative interest rate.
        VARIABLE_RATE = -0.05e18;
        deployEverlong();

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
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    function test_previewCloseLong_partial_maturity() external {
        // Deploy the everlong instance.
        deployEverlong();

        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpoints(POSITION_DURATION / 2, VARIABLE_RATE);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            everlong.asBase(),
            IEverlong.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    function test_previewCloseLong_partial_maturity_negative_interest()
        external
    {
        // Deploy the everlong instance with a negative interest rate.
        VARIABLE_RATE = -0.05e18;
        deployEverlong();

        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpoints(POSITION_DURATION / 2, VARIABLE_RATE);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            everlong.asBase(),
            IEverlong.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    function test_previewCloseLong_full_maturity() external {
        // Deploy the everlong instance.
        deployEverlong();

        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpoints(POSITION_DURATION, VARIABLE_RATE);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            everlong.asBase(),
            IEverlong.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }

    function test_previewCloseLong_full_maturity_negative_interest() external {
        // Deploy the everlong instance.
        VARIABLE_RATE = -0.05e18;
        deployEverlong();

        // Open a long.
        uint256 amount = 100e18;
        (uint256 maturityTime, uint256 bondAmount) = openLong(alice, amount);

        // Advance halfway through the term.
        advanceTimeWithCheckpoints(POSITION_DURATION, VARIABLE_RATE);

        // Ensure the preview amount underestimates the actual and is
        // within the tolerance.
        uint256 previewAssets = hyperdrive.previewCloseLong(
            everlong.asBase(),
            IEverlong.Position({
                maturityTime: maturityTime.toUint128(),
                bondAmount: bondAmount.toUint128()
            }),
            ""
        );
        uint256 actualAssets = closeLong(alice, maturityTime, bondAmount);
        assertEq(actualAssets, previewAssets);
    }
}
