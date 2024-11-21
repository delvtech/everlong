// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests the functionality around opening, closing, and valuing hyperdrive positions.
contract TestHyperdriveExecution is EverlongTest {
    using HyperdriveExecutionLibrary for IHyperdrive;
    using SafeCast for *;

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
}
