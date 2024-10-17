// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

contract ExampleTest is EverlongTest {
    using Lib for *;

    function setUp() public override {
        super.setUp();
        deployEverlong();
    }

    /// @dev Tests the following scenario:
    ///      1. First an innocent bystander deposits into Everlong. At that time, we
    ///         also call rebalance to invest Everlong's funds.
    ///      2. Next, an attacker opens a short. This should decrease Everlong's total
    ///         assets.
    ///      3. The attacker then deposits into Everlong. They should receive more
    ///         shares than the bystander.
    ///      4. Next, the attacker closes their short. They will lose some money on
    ///         fees due to this.
    ///      5. Finally, the attacker withdrawals from Everlong.
    function test_sandwich_short_instant() external {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The bystander deposits into Everlong.
        uint256 bystanderEverlongBasePaid = 500_000e18;
        uint256 bystanderShares = depositEverlong(
            bystanderEverlongBasePaid,
            bystander
        );

        // The attacker opens a large short.
        uint256 shortAmount = 100_000e18;
        (uint256 maturityTime, uint256 attackerShortBasePaid) = openShort(
            attacker,
            shortAmount
        );

        // The attacker deposits into Everlong.
        uint256 attackerEverlongBasePaid = 10_000e18;
        uint256 attackerShares = depositEverlong(
            attackerEverlongBasePaid,
            attacker
        );

        // The attacker closes their short position.
        uint256 attackerShortProceeds = closeShort(
            attacker,
            maturityTime,
            shortAmount
        );

        // The attacker redeems their Everlong shares.
        uint256 attackerEverlongProceeds = redeemEverlong(
            attackerShares,
            attacker
        );

        // The bystander redeems their Everlong shares.
        uint256 bystanderEverlongProceeds = redeemEverlong(
            bystanderShares,
            bystander
        );

        // Calculate the amount paid and the proceeds for the attacker.
        uint256 attackerPaid = attackerEverlongBasePaid + attackerShortBasePaid;
        uint256 attackerProceeds = attackerEverlongProceeds +
            attackerShortProceeds;

        // Ensure the attacker does not profit.
        assertLt(attackerProceeds, attackerPaid);
    }
}
