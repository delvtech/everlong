// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { stdMath } from "forge-std/StdMath.sol";
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

/// @dev Tests vault share price manipulation with the underlying hyperdrive instance.
contract VaultSharePriceManipulation is EverlongTest {
    using Packing for bytes32;
    using FixedPointMath for uint128;
    using FixedPointMath for uint256;
    using FixedPointMath for uint256;
    using Lib for *;
    using stdMath for *;

    struct SandwichParams {
        uint256 initialDeposit;
        uint256 bystanderDeposit;
        // Amount sandwicher spends on the short.
        uint256 sandwichShort;
        // Amount sandwicher deposits into everlong.
        uint256 sandwichDeposit;
        // Amount of time between attacker depositing into Everlong and
        // closing short.
        uint256 timeToCloseShort;
        // Amount of time between closing the short and Everlong.
        uint256 timeToCloseEverlong;
    }

    // function test_no_sandwich_instant() external {
    //     console.log("No Sandwich - Instant");
    //     quiznos(
    //         SandwichParams({
    //             initialDeposit: 100e18,
    //             bystanderDeposit: 100e18,
    //             sandwichShort: 0,
    //             sandwichDeposit: 100e18,
    //             timeToCloseShort: 0,
    //             timeToCloseEverlong: 0
    //         })
    //     );
    // }
    //
    // function test_no_sandwich_immature() external {
    //     console.log("No Sandwich - Immature");
    //     quiznos(
    //         SandwichParams({
    //             initialDeposit: 100e18,
    //             bystanderDeposit: 100e18,
    //             sandwichShort: 0,
    //             sandwichDeposit: 100e18,
    //             timeToCloseShort: 0,
    //             timeToCloseEverlong: POSITION_DURATION / 2
    //         })
    //     );
    // }
    //
    // function test_no_sandwich_mature() external {
    //     console.log("No Sandwich - Mature");
    //     quiznos(
    //         SandwichParams({
    //             initialDeposit: 100e18,
    //             bystanderDeposit: 100e18,
    //             sandwichShort: 0,
    //             sandwichDeposit: 100e18,
    //             timeToCloseShort: 0,
    //             timeToCloseEverlong: POSITION_DURATION + 1
    //         })
    //     );
    // }
    //

    function test_sandwich_instant() external {
        console.log("Sandwich - Instant");
        quiznos(
            SandwichParams({
                initialDeposit: 100e18,
                bystanderDeposit: 100e18,
                sandwichShort: 0,
                sandwichDeposit: 100e18,
                timeToCloseShort: 0,
                timeToCloseEverlong: 0
            })
        );
    }

    function test_sandwich_immature() external {
        console.log("Sandwich - Immature");
        quiznos(
            SandwichParams({
                initialDeposit: 100e18,
                bystanderDeposit: 100e18,
                sandwichShort: 0,
                sandwichDeposit: 100e18,
                timeToCloseShort: 0,
                timeToCloseEverlong: POSITION_DURATION / 2
            })
        );
    }

    function test_sandwich_mature() external {
        console.log("Sandwich - Mature");
        quiznos(
            SandwichParams({
                initialDeposit: 100e18,
                bystanderDeposit: 100e18,
                sandwichShort: 0,
                sandwichDeposit: 100e18,
                timeToCloseShort: 0,
                timeToCloseEverlong: POSITION_DURATION + 1
            })
        );
    }

    function quiznos(SandwichParams memory _params) internal {
        // Deploy Everlong.
        // deployEverlong();

        // Deploy EverlongUpdateOnRebalance.
        deployEverlongUpdateOnRebalance();

        // console.log("------------------------------------------------------");
        console.log("Initial Deposit:     %e", _params.initialDeposit);
        console.log("Bystander Deposit:   %e", _params.bystanderDeposit);
        console.log("Sandwich Short:      %e", _params.sandwichShort);
        console.log("Sandwich Deposit:    %e", _params.sandwichDeposit);
        console.log("Time Close Short:    %s", _params.timeToCloseShort);
        console.log("Time Close Everlong: %s", _params.timeToCloseEverlong);

        // Initial deposit is made into everlong.
        uint256 celineShares = depositEverlong(_params.initialDeposit, celine);

        // Innocent bystander deposits into everlong.
        uint256 aliceShares = depositEverlong(_params.bystanderDeposit, alice);

        // Attacker opens a short on hyperdrive.
        uint256 bobShortMaturityTime;
        uint256 bobShortAmount;
        if (_params.sandwichShort > 0) {
            (bobShortMaturityTime, bobShortAmount) = openShort(
                bob,
                _params.sandwichShort
            );
        }

        // Attacker deposits into everlong.
        uint256 bobEverlongShares = depositEverlong(
            _params.sandwichDeposit,
            bob
        );

        if (_params.timeToCloseShort > 0) {
            advanceTime(_params.timeToCloseShort, VARIABLE_RATE);
            if (everlong.canRebalance()) {
                everlong.rebalance();
            }
        }

        // Attacker closes short on hyperdrive.
        uint256 bobProceedsShort;
        if (_params.sandwichShort > 0) {
            bobProceedsShort = closeShort(
                bob,
                bobShortMaturityTime,
                bobShortAmount
            );
        }

        if (_params.timeToCloseEverlong > 0) {
            advanceTime(_params.timeToCloseEverlong, VARIABLE_RATE);
            if (everlong.canRebalance()) {
                everlong.rebalance();
            }
        }

        // Attacker redeems from everlong.
        uint256 bobProceedsEverlong = redeemEverlong(bobEverlongShares, bob);

        // Innocent bystander redeems from everlong.
        uint256 aliceProceeds = redeemEverlong(aliceShares, alice);

        console.log(
            "share delta percent:   %e",
            (
                bobEverlongShares > aliceShares
                    ? int256(bobEverlongShares.percentDelta(aliceShares))
                    : -1 * int256(bobEverlongShares.percentDelta(aliceShares))
            )
        );
        console.log(
            "bystander profits:  %e",
            int256(
                _params.bystanderDeposit > aliceProceeds
                    ? -1 *
                        int256(
                            aliceProceeds.percentDelta(_params.bystanderDeposit)
                        )
                    : int256(
                        aliceProceeds.percentDelta(_params.bystanderDeposit)
                    )
            )
        );
        console.log(
            "attacker profits:   %e",
            int256(
                _params.sandwichDeposit > bobProceedsEverlong
                    ? -1 *
                        int256(
                            bobProceedsEverlong.percentDelta(
                                _params.sandwichDeposit
                            )
                        )
                    : int256(
                        bobProceedsEverlong.percentDelta(
                            _params.sandwichDeposit
                        )
                    )
            )
        );
        console.log("------------------------------------------------------");
    }
}
