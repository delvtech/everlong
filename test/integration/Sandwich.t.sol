// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

contract Sandwich is EverlongTest {
    using Lib for *;
    using HyperdriveUtils for *;

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
        redeemEverlong(bystanderShares, bystander);

        // Calculate the amount paid and the proceeds for the attacker.
        uint256 attackerPaid = attackerEverlongBasePaid + attackerShortBasePaid;
        uint256 attackerProceeds = attackerEverlongProceeds +
            attackerShortProceeds;

        // Ensure the attacker does not profit.
        assertLt(attackerProceeds, attackerPaid);
    }

    function testFuzz_sandwich_short_instant(
        uint256 _shortAmount,
        uint256 _attackerDepositAmount,
        uint256 _bystanderDepositAmount
    ) external {
        // Limit the range of values for the fuzz test.

        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The bystander deposits into Everlong.
        _bystanderDepositAmount = bound(
            _bystanderDepositAmount,
            1e18,
            hyperdrive.calculateMaxLong() / 10
        );
        uint256 bystanderShares = depositEverlong(
            _bystanderDepositAmount,
            bystander
        );

        // The attacker opens a large short.
        _shortAmount = bound(
            _shortAmount,
            1e18,
            hyperdrive.calculateMaxShort() / 10
        );
        (uint256 maturityTime, uint256 attackerShortBasePaid) = openShort(
            attacker,
            _shortAmount
        );

        // The attacker deposits into Everlong.
        _attackerDepositAmount = bound(
            _attackerDepositAmount,
            1e18,
            hyperdrive.calculateMaxLong() / 10
        );
        uint256 attackerShares = depositEverlong(
            _attackerDepositAmount,
            attacker
        );

        // The attacker closes their short position.
        uint256 attackerShortProceeds = closeShort(
            attacker,
            maturityTime,
            _shortAmount
        );

        // The attacker redeems their Everlong shares.
        uint256 attackerEverlongProceeds = redeemEverlong(
            attackerShares,
            attacker
        );

        // The bystander redeems their Everlong shares.
        redeemEverlong(bystanderShares, bystander);

        // Calculate the amount paid and the proceeds for the attacker.
        uint256 attackerPaid = _attackerDepositAmount + attackerShortBasePaid;
        uint256 attackerProceeds = attackerEverlongProceeds +
            attackerShortProceeds;

        // Ensure the attacker does not profit.
        assertLt(attackerProceeds, attackerPaid);
    }

    /// @dev Tests the following scenario:
    ///      1. Attacker adds liquidity.
    ///      2. Bystander deposits.
    ///      3. Attacker deposits.
    ///      4. Attacker removes liquidity.
    ///      5. Attacker withdraws.
    ///      6. Bystander withdraws.
    function test_sandwich_lp_instant() external {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The attacker adds liquidity to Hyperdrive.
        uint256 attackerLPPaid = 500_000e18;
        uint256 attackerLPShares = addLiquidity(attacker, attackerLPPaid);

        // The bystander deposits into Everlong.
        uint256 bystanderEverlongPaid = 500_000e18;
        uint256 bystanderEverlongShares = depositEverlong(
            bystanderEverlongPaid,
            bystander
        );

        // The attacker deposits into Everlong.
        uint256 attackerEverlongPaid = 1_000e18;
        uint256 attackerEverlongShares = depositEverlong(
            attackerEverlongPaid,
            attacker
        );

        // The attacker removes liquidity from Hyperdrive.
        (
            uint256 attackerLPProceeds,
            uint256 attackerLPWithdrawalShares
        ) = removeLiquidity(attacker, attackerLPShares);
        console.log(
            "Withdrawal Shares: %s",
            attackerLPWithdrawalShares.toString(18)
        );

        // The attacker redeems from Everlong.
        uint256 attackerEverlongProceeds = redeemEverlong(
            attackerEverlongShares,
            attacker
        );

        console.log("CanRebalance: %s", everlong.canRebalance());
        everlong.rebalance();

        // The bystander redeems from Everlong.
        uint256 bystanderEverlongProceeds = redeemEverlong(
            bystanderEverlongShares,
            bystander
        );

        // Log the results.
        console.log(
            "attacker paid      = %s",
            (attackerEverlongPaid + attackerLPPaid).toString(18)
        );
        console.log(
            "attacker proceeds  = %s",
            (attackerEverlongProceeds + attackerLPProceeds).toString(18)
        );
        console.log(
            "attacker everlong  = %s",
            attackerEverlongProceeds.toString(18)
        );
        console.log("attacker lp        = %s", attackerLPProceeds.toString(18));
        console.log(
            "bystander paid     = %s",
            bystanderEverlongPaid.toString(18)
        );
        console.log(
            "bystander proceeds = %s",
            bystanderEverlongProceeds.toString(18)
        );
    }

    function testFuzz_sandwich_lp_instant(
        uint256 _lpDeposit,
        uint256 _bystanderDeposit,
        uint256 _attackerDeposit
    ) external {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The attacker adds liquidity to Hyperdrive.
        _lpDeposit = bound(_lpDeposit, 1e18, INITIAL_CONTRIBUTION);
        uint256 attackerLPShares = addLiquidity(attacker, _lpDeposit);

        // The bystander deposits into Everlong.
        _bystanderDeposit = bound(
            _bystanderDeposit,
            1e18,
            hyperdrive.calculateMaxLong() / 10
        );
        uint256 bystanderEverlongShares = depositEverlong(
            _bystanderDeposit,
            bystander
        );

        // The attacker deposits into Everlong.
        _attackerDeposit = bound(
            _attackerDeposit,
            1e18,
            hyperdrive.calculateMaxLong() / 10
        );
        uint256 attackerEverlongShares = depositEverlong(
            _attackerDeposit,
            attacker
        );

        // The attacker removes liquidity from Hyperdrive.
        (
            uint256 attackerLPProceeds,
            uint256 attackerLPWithdrawalShares
        ) = removeLiquidity(attacker, attackerLPShares);

        // The attacker redeems from Everlong.
        uint256 attackerEverlongProceeds = redeemEverlong(
            attackerEverlongShares,
            attacker
        );

        everlong.rebalance();

        // The bystander redeems from Everlong.
        uint256 bystanderEverlongProceeds = redeemEverlong(
            bystanderEverlongShares,
            bystander
        );

        assertLt(attackerEverlongProceeds, _attackerDeposit);
    }
}
