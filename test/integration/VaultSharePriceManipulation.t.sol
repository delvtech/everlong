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

/// @dev Tests vault share price manipulation with the underlying hyperdrive instance.
contract VaultSharePriceManipulation is EverlongTest {
    using Packing for bytes32;
    using FixedPointMath for uint128;
    using FixedPointMath for uint256;
    using Lib for *;

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

    function test_sandwich_instant() external {
        quiznos(
            SandwichParams({
                initialDeposit: 100e18,
                bystanderDeposit: 100e18,
                sandwichShort: 100e18,
                sandwichDeposit: 100e18,
                timeToCloseShort: 0,
                timeToCloseEverlong: 0
            })
        );
    }

    function quiznos(SandwichParams memory _params) internal {
        // Deploy Everlong.
        deployEverlong();

        console.log("------------------------------------------------------");
        console.log("Initial Deposit:     %s", _params.initialDeposit);
        console.log("Bystander Deposit:   %s", _params.bystanderDeposit);
        console.log("Sandwich Short:      %s", _params.sandwichShort);
        console.log("Sandwich Deposit:    %s", _params.sandwichDeposit);
        console.log("Time Close Short:    %s", _params.timeToCloseShort);
        console.log("Time Close Everlong: %s", _params.timeToCloseEverlong);
        console.log(" ");

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
        }

        // Attacker redeems from everlong.
        uint256 bobProceedsEverlong = redeemEverlong(bobEverlongShares, bob);

        // Innocent bystander redeems from everlong.
        uint256 aliceProceeds = redeemEverlong(aliceShares, alice);

        console.log("bystander shares:   %s", aliceShares);
        console.log("attacker shares:    %s", bobEverlongShares);
        console.log("bystander proceeds: %s", aliceProceeds);
        console.log("attacker proceeds:  %s", bobProceedsEverlong);
        console.log("------------------------------------------------------");
    }
}
