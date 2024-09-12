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

    function test_short_hyperdrive_everlong() external {
        // Deploy Everlong.
        deployEverlong();

        uint256 bystanderEverlongDeposit = 100e18;
        uint256 attackerShort = 100e18;
        uint256 attackerEverlongDeposit = 100e18;

        // Innocent bystander deposits into everlong.
        uint256 aliceShares = depositEverlong(bystanderEverlongDeposit, alice);

        // Attacker opens a short on hyperdrive.
        (uint256 bobShortMaturityTime, uint256 bobShortAmount) = openShort(
            bob,
            attackerShort
        );

        // Attacker deposits into everlong.
        uint256 bobEverlongShares = depositEverlong(
            attackerEverlongDeposit,
            bob
        );

        // Attacker closes short on hyperdrive.
        uint256 bobProceedsShort = closeShort(
            bob,
            bobShortMaturityTime,
            bobShortAmount
        );

        // Attacker redeems from everlong.
        uint256 bobProceedsEverlong = redeemEverlong(bobEverlongShares, bob);

        // Innocent bystander redeems from everlong.
        uint256 aliceProceeds = redeemEverlong(aliceShares, alice);

        console.log("bob proceeds e:   %s", bobProceedsEverlong);
        console.log("bob short amnt:   %s", bobShortAmount);
        console.log("bob proceeds h:   %s", bobProceedsShort);
        console.log("alice proceeds:   %s", aliceProceeds);
    }
}
