// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

// TODO: Add sandwich tests around withdraw/redeem.
contract TestSandwich is EverlongTest {
    using Lib for *;
    using HyperdriveUtils for *;

    /// @dev Tests the short sandwich scenario with no idle liquidity.
    function testFuzz_sandwich_short_instant_no_idle(
        uint256 _shortAmount,
        uint256 _attackerDepositAmount,
        uint256 _bystanderDepositAmount
    ) external {
        TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 0;
        MIN_IDLE_LIQUIDITY_BASIS_POINTS = 0;
        sandwich_short_instant(
            _shortAmount,
            _attackerDepositAmount,
            _bystanderDepositAmount
        );
    }

    /// @dev Tests the short sandwich scenario with idle liquidity.
    function testFuzz_sandwich_short_instant_idle(
        uint256 _shortAmount,
        uint256 _attackerDepositAmount,
        uint256 _bystanderDepositAmount
    ) external {
        TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 1_000;
        MIN_IDLE_LIQUIDITY_BASIS_POINTS = 2_000;
        sandwich_short_instant(
            _shortAmount,
            _attackerDepositAmount,
            _bystanderDepositAmount
        );
    }

    /// @dev Tests the lp sandwich scenario with no idle liquidity.
    function testFuzz_sandwich_lp_instant_no_idle(
        uint256 _lpDeposit,
        uint256 _attackerDepositAmount,
        uint256 _bystanderDepositAmount
    ) external {
        TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 0;
        MIN_IDLE_LIQUIDITY_BASIS_POINTS = 0;
        sandwich_lp_instant(
            _lpDeposit,
            _attackerDepositAmount,
            _bystanderDepositAmount
        );
    }

    /// @dev Tests the lp sandwich scenario with idle liquidity.
    function testFuzz_sandwich_lp_instant_idle(
        uint256 _lpDeposit,
        uint256 _attackerDepositAmount,
        uint256 _bystanderDepositAmount
    ) external {
        TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 1_000;
        MIN_IDLE_LIQUIDITY_BASIS_POINTS = 2_000;
        sandwich_lp_instant(
            _lpDeposit,
            _attackerDepositAmount,
            _bystanderDepositAmount
        );
    }

    // TODO: Decrease min range to Hyperdrive `MINIMUM_TRANSACTION_AMOUNT`.
    //
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
    function sandwich_short_instant(
        uint256 _shortAmount,
        uint256 _attackerDepositAmount,
        uint256 _bystanderDepositAmount
    ) public {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The bystander deposits into Everlong.
        _bystanderDepositAmount = bound(
            _bystanderDepositAmount,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 bystanderShares = depositStrategy(
            _bystanderDepositAmount,
            bystander,
            true
        );

        // The attacker opens a large short.
        _shortAmount = bound(
            _shortAmount,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxShort() / 2
        );
        (uint256 maturityTime, uint256 attackerShortBasePaid) = openShort(
            attacker,
            _shortAmount
        );

        // The attacker deposits into Everlong.
        _attackerDepositAmount = bound(
            _attackerDepositAmount,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 attackerShares = depositStrategy(
            _attackerDepositAmount,
            attacker,
            true
        );

        // The attacker closes their short position.
        uint256 attackerShortProceeds = closeShort(
            attacker,
            maturityTime,
            _shortAmount
        );

        // The attacker redeems their Everlong shares.
        uint256 attackerEverlongProceeds = redeemStrategy(
            attackerShares,
            attacker,
            true
        );

        // The bystander redeems their Everlong shares.
        redeemStrategy(bystanderShares, bystander, true);

        // Calculate the amount paid and the proceeds for the attacker.
        uint256 attackerPaid = _attackerDepositAmount + attackerShortBasePaid;
        uint256 attackerProceeds = attackerEverlongProceeds +
            attackerShortProceeds;

        // Ensure the attacker does not profit.
        assertLe(attackerProceeds, attackerPaid);
    }

    // TODO: Decrease min range to Hyperdrive `MINIMUM_TRANSACTION_AMOUNT`.
    //
    /// @dev Tests the following scenario:
    ///      1. Attacker adds liquidity.
    ///      2. Bystander deposits.
    ///      3. Attacker deposits.
    ///      4. Attacker removes liquidity.
    ///      5. Attacker withdraws.
    ///      6. Bystander withdraws.
    function sandwich_lp_instant(
        uint256 _lpDeposit,
        uint256 _bystanderDeposit,
        uint256 _attackerDeposit
    ) public {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The attacker adds liquidity to Hyperdrive.
        _lpDeposit = bound(
            _lpDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            INITIAL_CONTRIBUTION
        );
        uint256 attackerLPShares = addLiquidity(attacker, _lpDeposit);

        // The bystander deposits into Everlong.
        _bystanderDeposit = bound(
            _bystanderDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 bystanderEverlongShares = depositStrategy(
            _bystanderDeposit,
            bystander,
            true
        );

        // The attacker deposits into Everlong.
        _attackerDeposit = bound(
            _attackerDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 attackerEverlongShares = depositStrategy(
            _attackerDeposit,
            attacker,
            true
        );

        // The attacker removes liquidity from Hyperdrive.
        removeLiquidity(attacker, attackerLPShares);

        // The attacker redeems from Everlong.
        uint256 attackerEverlongProceeds = redeemStrategy(
            attackerEverlongShares,
            attacker,
            true
        );

        // The bystander redeems from Everlong.
        //
        // While not needed for the assertion below, it's included to ensure
        // that the attack does not prevent the bystander from redeeming their
        // shares.
        redeemStrategy(bystanderEverlongShares, bystander, true);

        // Ensure that the attacker does not profit from their actions.
        assertLe(attackerEverlongProceeds, _attackerDeposit);
    }
}
