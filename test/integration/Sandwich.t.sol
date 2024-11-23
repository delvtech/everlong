// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Helper functions for testing sandwich scenarios.
///      No tests are in this file.
contract TestSandwichHelper is EverlongTest {
    using FixedPointMath for *;
    using Lib for *;
    using HyperdriveExecutionLibrary for *;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                            Short Sandwich                             │
    // ╰───────────────────────────────────────────────────────────────────────╯

    // TODO: Decrease min range to Hyperdrive `MINIMUM_TRANSACTION_AMOUNT`.
    //
    /// @dev Tests the following scenario:
    ///      1. Bystander deposits into Everlong.
    ///      2. Attacker opens a short.
    ///         This decreases the present value of Everlong's bond portfolio.
    ///      3. The attacker then deposits into Everlong.
    ///      4. Attacker closes their short.
    ///         This increases the present value of Everlong's bond portfolio.
    ///      5. Attacker redeems from Everlong.
    function sandwich_short_deposit_instant(
        uint256 _shortAmount,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) public {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The bystander deposits into Everlong.
        _bystanderDeposit = bound(
            _bystanderDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 bystanderShares = depositVault(
            _bystanderDeposit,
            bystander,
            true
        );

        // The attacker opens a large short.
        _shortAmount = bound(
            _shortAmount,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            HyperdriveUtils.calculateMaxShort(hyperdrive) / 2
        );
        (uint256 maturityTime, uint256 attackerShortBasePaid) = openShort(
            attacker,
            _shortAmount
        );

        // The attacker deposits into Everlong.
        // NOTE: We do not rebalance after this deposit since it will be atomic
        // with the rest of the sandwich.
        _attackerDeposit = bound(
            _attackerDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 attackerShares = depositVault(
            _attackerDeposit,
            attacker,
            false
        );

        // The attacker closes their short position.
        uint256 attackerShortProceeds = closeShort(
            attacker,
            maturityTime,
            _shortAmount
        );

        // The attacker redeems their Everlong shares.
        uint256 attackerEverlongProceeds = redeemVault(
            attackerShares,
            attacker,
            true
        );

        // The bystander redeems their Everlong shares.
        redeemVault(bystanderShares, bystander, true);

        // Calculate the amount paid and the proceeds for the attacker.
        uint256 attackerPaid = _attackerDeposit + attackerShortBasePaid;
        uint256 attackerProceeds = attackerEverlongProceeds +
            attackerShortProceeds;

        // Ensure the attacker does not profit.
        assertLe(attackerProceeds, attackerPaid);
    }

    // TODO: Decrease min range to Hyperdrive `MINIMUM_TRANSACTION_AMOUNT`.
    //
    /// @dev Tests the following scenario:
    ///      1. The innocent bystander deposits into Everlong.
    ///      2. The attacker deposits into Everlong.
    ///      3. The attacker opens a short.
    ///         This decreases the present value of Everlong's bond portfolio.
    ///      4. The innocent bystander redeems from Everlong.
    ///      5. The attacker closes their short.
    ///         This increases the present value of Everlong's bond portfolio.
    ///      6. The attacker redeems from Everlong.
    function sandwich_short_redeem_instant(
        uint256 _shortAmount,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) public {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The bystander deposits into Everlong.
        _bystanderDeposit = bound(
            _bystanderDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 bystanderShares = depositVault(
            _bystanderDeposit,
            bystander,
            true
        );

        // The attacker deposits into Everlong.
        // NOTE: We do not rebalance after this deposit since it will be atomic
        // with the rest of the sandwich.
        _attackerDeposit = bound(
            _attackerDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 attackerShares = depositVault(
            _attackerDeposit,
            attacker,
            false
        );

        // The attacker opens a short.
        _shortAmount = bound(
            _shortAmount,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            HyperdriveUtils.calculateMaxShort(hyperdrive) / 2
        );
        (uint256 maturityTime, ) = openShort(attacker, _shortAmount);

        // The bystander redeems their Everlong shares.
        // NOTE: We do not rebalance after this redemption since it will be atomic
        // with the rest of the sandwich.
        redeemVault(bystanderShares, bystander, false);

        // The attacker closes their short position.
        closeShort(attacker, maturityTime, _shortAmount);

        // The attacker redeems their Everlong shares.
        uint256 attackerEverlongProceeds = redeemVault(
            attackerShares,
            attacker,
            true
        );

        // Ensure the attacker does not profit from their Everlong position.
        assertLe(attackerEverlongProceeds, _attackerDeposit);
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              LP Sandwich                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    // TODO: Decrease min range to Hyperdrive `MINIMUM_TRANSACTION_AMOUNT`.
    //
    /// @dev Tests the following scenario:
    ///      1. Attacker adds liquidity.
    ///         This decreases the present value of Everlong's bond portfolio.
    ///      2. Bystander deposits.
    ///      3. Attacker deposits.
    ///      4. Attacker removes liquidity.
    ///         This increases the present value of Everlong's bond portfolio.
    ///      5. Attacker withdraws.
    ///      6. Bystander withdraws.
    function sandwich_lp_deposit_instant(
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
        // NOTE: We do not rebalance after this deposit since it will be atomic
        // with the rest of the sandwich.
        _bystanderDeposit = bound(
            _bystanderDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 bystanderEverlongShares = depositVault(
            _bystanderDeposit,
            bystander,
            false
        );

        // The attacker deposits into Everlong.
        // NOTE: We do not rebalance after this deposit since it will be atomic
        // with the rest of the sandwich.
        _attackerDeposit = bound(
            _attackerDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 attackerEverlongShares = depositVault(
            _attackerDeposit,
            attacker,
            false
        );

        // The attacker removes liquidity from Hyperdrive.
        removeLiquidity(attacker, attackerLPShares);

        // The attacker redeems from Everlong.
        uint256 attackerEverlongProceeds = redeemVault(
            attackerEverlongShares,
            attacker,
            true
        );

        // The bystander redeems from Everlong.
        //
        // While not needed for the assertion below, it's included to ensure
        // that the attack does not prevent the bystander from redeeming their
        // shares.
        redeemVault(bystanderEverlongShares, bystander, true);

        // Ensure that the attacker does not profit from their actions.
        assertLe(attackerEverlongProceeds, _attackerDeposit);
    }

    // TODO: Decrease min range to Hyperdrive `MINIMUM_TRANSACTION_AMOUNT`.
    //
    /// @dev Tests the following scenario:
    ///      1. The innocent bystander deposits into Everlong.
    ///      2. The attacker deposits into Everlong.
    ///      3. The attacker adds liquidity.
    ///         This decreases the present value of Everlong's bond portfolio.
    ///      4. The innocent bystander redeems from Everlong.
    ///      5. The attacker removes liquidity.
    ///         This increases the present value of Everlong's bond portfolio.
    ///      6. The attacker redeems from Everlong.
    function sandwich_lp_redeem_instant(
        uint256 _lpDeposit,
        uint256 _bystanderDeposit,
        uint256 _attackerDeposit
    ) public {
        // Alice is the attacker, and Bob is the bystander.
        address attacker = alice;
        address bystander = bob;

        // The bystander deposits into Everlong.
        _bystanderDeposit = bound(
            _bystanderDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 bystanderShares = depositVault(
            _bystanderDeposit,
            bystander,
            true
        );

        // The attacker deposits into Everlong.
        // NOTE: We do not rebalance after this deposit since it will be atomic
        // with the rest of the sandwich.
        _attackerDeposit = bound(
            _attackerDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            hyperdrive.calculateMaxLong() / 3
        );
        uint256 attackerShares = depositVault(
            _attackerDeposit,
            attacker,
            false
        );

        // The attacker adds liquidity.
        _lpDeposit = bound(
            _lpDeposit,
            MINIMUM_TRANSACTION_AMOUNT * 5,
            HyperdriveUtils.calculateMaxShort(hyperdrive) / 2
        );
        uint256 attackerLPShares = addLiquidity(attacker, _lpDeposit);

        // The bystander redeems their Everlong shares.
        // NOTE: We do not rebalance after this redemption since it will be atomic
        // with the rest of the sandwich.
        redeemVault(bystanderShares, bystander, false);

        // The attacker removes liquidity.
        removeLiquidity(attacker, attackerLPShares);

        // The attacker redeems their Everlong shares.
        uint256 attackerEverlongProceeds = redeemVault(
            attackerShares,
            attacker,
            true
        );

        // Ensure the attacker does not profit from their Everlong position.
        assertLe(attackerEverlongProceeds, _attackerDeposit);
    }
}

/// @dev Tests LP and Short sandwich attacks around Everlong vault deposits and
///      redemptions with zero vault idle liquidity.
contract TestSandwichNoIdle is TestSandwichHelper {
    using FixedPointMath for *;
    using Lib for *;
    using HyperdriveExecutionLibrary for *;

    function setUp() public override {
        // Redeploy Hyperdrive + Everlong with specified idle configuration.
        TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 0;
        MIN_IDLE_LIQUIDITY_BASIS_POINTS = 0;
        super.setUp();
    }

    /// @dev Tests the short deposit sandwich scenario with no idle liquidity.
    function testFuzz_sandwich_short_deposit_instant_no_idle(
        uint256 _shortAmount,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_short_deposit_instant(
            _shortAmount,
            _attackerDeposit,
            _bystanderDeposit
        );
    }

    /// @dev Tests the short redeem sandwich scenario with no idle liquidity.
    function testFuzz_sandwich_short_redeem_instant_no_idle(
        uint256 _shortAmount,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_short_redeem_instant(
            _shortAmount,
            _attackerDeposit,
            _bystanderDeposit
        );
    }

    /// @dev Tests the lp deposit sandwich scenario with no idle liquidity.
    function testFuzz_sandwich_lp_deposit_instant_no_idle(
        uint256 _lpDeposit,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_lp_deposit_instant(
            _lpDeposit,
            _attackerDeposit,
            _bystanderDeposit
        );
    }

    /// @dev Tests the lp redeem sandwich scenario with no idle liquidity.
    function testFuzz_sandwich_lp_redeem_instant_no_idle(
        uint256 _lpDeposit,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_lp_redeem_instant(
            _lpDeposit,
            _attackerDeposit,
            _bystanderDeposit
        );
    }
}

/// @dev Tests LP and Short sandwich attacks around Everlong vault deposits and
///      redemptions with zero vault idle liquidity.
contract TestSandwichIdle is TestSandwichHelper {
    using FixedPointMath for *;
    using Lib for *;
    using HyperdriveExecutionLibrary for *;

    function setUp() public override {
        // Redeploy Hyperdrive + Everlong with specified idle configuration.
        TARGET_IDLE_LIQUIDITY_BASIS_POINTS = 2_000;
        MIN_IDLE_LIQUIDITY_BASIS_POINTS = 1_000;
        super.setUp();
    }

    /// @dev Tests the short deposit sandwich scenario.
    function testFuzz_sandwich_short_deposit_instant_idle(
        uint256 _shortAmount,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_short_deposit_instant(
            _shortAmount,
            _attackerDeposit,
            _bystanderDeposit
        );
    }

    /// @dev Tests the short redeem sandwich scenario with idle liquidity.
    function testFuzz_sandwich_short_redeem_instant_idle(
        uint256 _shortAmount,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_short_redeem_instant(
            _shortAmount,
            _attackerDeposit,
            _bystanderDeposit
        );
    }

    /// @dev Tests the lp deposit sandwich scenario with idle liquidity.
    function testFuzz_sandwich_lp_deposit_instant_idle(
        uint256 _lpDeposit,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_lp_deposit_instant(
            _lpDeposit,
            _attackerDeposit,
            _bystanderDeposit
        );
    }

    /// @dev Tests the lp redeem sandwich scenario with idle liquidity.
    function testFuzz_sandwich_lp_redeem_instant_idle(
        uint256 _lpDeposit,
        uint256 _attackerDeposit,
        uint256 _bystanderDeposit
    ) external {
        // Run the test scenario.
        sandwich_lp_redeem_instant(
            _lpDeposit,
            _attackerDeposit,
            _bystanderDeposit
        );
    }
}
