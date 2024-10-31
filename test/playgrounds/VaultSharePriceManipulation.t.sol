// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { stdMath } from "forge-std/StdMath.sol";
import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { HyperdriveMath } from "hyperdrive/contracts/src/libraries/HyperdriveMath.sol";
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
contract TestVaultSharePriceManipulation is EverlongTest {
    using Packing for bytes32;
    using FixedPointMath for uint128;
    using FixedPointMath for uint256;
    using FixedPointMath for uint256;
    using Lib for *;
    using stdMath for *;
    using HyperdriveUtils for *;

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
        // Amount of time between attacker closing the short and closing their
        // Everlong position.
        uint256 timeToCloseEverlong;
        // Amount of time between attacker closing their Everlong position
        // and the bystander closing their Everlong position.
        uint256 bystanderCloseDelay;
    }

    SandwichParams params =
        SandwichParams({
            initialDeposit: 0,
            bystanderDeposit: 0,
            sandwichShort: 0,
            sandwichDeposit: 0,
            timeToCloseShort: 0,
            timeToCloseEverlong: 0,
            bystanderCloseDelay: 0
        });

    IHyperdrive.PoolConfig poolConfig;

    uint256[] fixedRates;
    int256[] variableRates;

    function test_sandwichScenarios() external {
        // Skip this test unless disabled manually.
        vm.skip(true);

        console.log(
            "hyperdrive_liquidity,fixed_rate,variable_rate,timestretch,curve_fee,flat_fee,initial_deposit,bystander_deposit,sandwich_short,sandwich_deposit,time_to_close_short,time_to_close_everlong,bystander_close_delay,sandwich_short_cost,attacker_balance,bystander_balance,initial_depositor_balance,everlong_balance"
        );

        fixedRates.push(0.025e18);
        fixedRates.push(0.05e18);
        fixedRates.push(0.1e18);
        variableRates.push(0.025e18);
        variableRates.push(0.05e18);
        variableRates.push(0.1e18);

        for (uint256 i = 0; i < fixedRates.length; i++) {
            FIXED_RATE = fixedRates[i];
            for (uint256 j = 0; j < variableRates.length; j++) {
                VARIABLE_RATE = variableRates[j];

                // ── With Fees ──────────────────────────────────────────────

                updatePoolConfig();

                // Base
                sandwichScenarios();

                // Double TimeStretch
                poolConfig.timeStretch = poolConfig.timeStretch * 2;
                sandwichScenarios();

                // Half TimeStretch
                poolConfig.timeStretch = poolConfig.timeStretch / 4;
                sandwichScenarios();

                // ── Without Fees ───────────────────────────────────────────

                poolConfig = testConfig(FIXED_RATE, POSITION_DURATION);

                // Base
                sandwichScenarios();

                // Double TimeStretch
                poolConfig.timeStretch = poolConfig.timeStretch * 2;
                sandwichScenarios();

                // Half TimeStretch
                poolConfig.timeStretch = poolConfig.timeStretch / 4;
                sandwichScenarios();
            }
        }
    }

    function updatePoolConfig() internal {
        poolConfig = testConfig(FIXED_RATE, POSITION_DURATION);
        poolConfig.fees = IHyperdrive.Fees({
            curve: CURVE_FEE,
            flat: FLAT_FEE,
            governanceLP: GOVERNANCE_LP_FEE,
            governanceZombie: GOVERNANCE_ZOMBIE_FEE
        });
    }

    function sandwichScenarios() internal {
        // No Attack
        params = SandwichParams({
            initialDeposit: 100e18,
            bystanderDeposit: 100e18,
            sandwichShort: 0,
            sandwichDeposit: 100e18,
            timeToCloseShort: 0,
            timeToCloseEverlong: 0,
            bystanderCloseDelay: 0
        });
        varyTiming();

        // Base Attack
        params = SandwichParams({
            initialDeposit: 100e18,
            bystanderDeposit: 100e18,
            sandwichShort: 100e18,
            sandwichDeposit: 100e18,
            timeToCloseShort: 0,
            timeToCloseEverlong: 0,
            bystanderCloseDelay: 0
        });
        varyTiming();

        // Increased Initial Deposit Amount
        params = SandwichParams({
            initialDeposit: 1_000e18,
            bystanderDeposit: 100e18,
            sandwichShort: 100e18,
            sandwichDeposit: 100e18,
            timeToCloseShort: 0,
            timeToCloseEverlong: 0,
            bystanderCloseDelay: 0
        });
        varyTiming();

        // Increased Sandwich Short Amount
        params = SandwichParams({
            initialDeposit: 100e18,
            bystanderDeposit: 100e18,
            sandwichShort: 1_000e18,
            sandwichDeposit: 100e18,
            timeToCloseShort: 0,
            timeToCloseEverlong: 0,
            bystanderCloseDelay: 0
        });
        varyTiming();

        // Super-Increased Sandwich Short Amount
        params = SandwichParams({
            initialDeposit: 100e18,
            bystanderDeposit: 100e18,
            sandwichShort: 15_000e18,
            sandwichDeposit: 100e18,
            timeToCloseShort: 0,
            timeToCloseEverlong: 0,
            bystanderCloseDelay: 0
        });
        varyTiming();

        // Increased Sandwich Deposit Amount
        params = SandwichParams({
            initialDeposit: 100e18,
            bystanderDeposit: 100e18,
            sandwichShort: 100e18,
            sandwichDeposit: 1_000e18,
            timeToCloseShort: 0,
            timeToCloseEverlong: 0,
            bystanderCloseDelay: 0
        });
        varyTiming();
    }

    function varyTiming() internal {
        string memory profits = "";

        // Short: Close Immediately
        // Everlong: Close Immediately
        // Bystander: Close Immediately
        params.timeToCloseShort = 0;
        params.timeToCloseEverlong = 0;
        params.bystanderCloseDelay = 0;
        profits = sandwich();
        logCSVRow(profits);

        // Short: Close Immediately
        // Everlong: Close Half Term
        // Bystander: Close Half Term
        params.timeToCloseShort = 0;
        params.timeToCloseEverlong = POSITION_DURATION / 2;
        params.bystanderCloseDelay = 0;
        profits = sandwich();
        logCSVRow(profits);

        // Short: Close Immediately
        // Everlong: Close Half Term
        // Bystander: Close Full Term
        params.timeToCloseShort = 0;
        params.timeToCloseEverlong = POSITION_DURATION / 2;
        params.bystanderCloseDelay = POSITION_DURATION / 2 + 1;
        profits = sandwich();
        logCSVRow(profits);

        // Short: Close Immediately
        // Everlong: Close Full Term
        // Bystander: Close Full Term
        params.timeToCloseShort = 0;
        params.timeToCloseEverlong = POSITION_DURATION + 1;
        params.bystanderCloseDelay = 0;
        profits = sandwich();
        logCSVRow(profits);

        // Short: Close Half Term
        // Everlong: Close Half Term
        // Bystander: Close Half Term
        params.timeToCloseShort = POSITION_DURATION / 2;
        params.timeToCloseEverlong = 0;
        params.bystanderCloseDelay = 0;
        profits = sandwich();
        logCSVRow(profits);

        // Short: Close Half Term
        // Everlong: Close Full Term
        // Bystander: Close Full Term
        params.timeToCloseShort = POSITION_DURATION / 2;
        params.timeToCloseEverlong = POSITION_DURATION / 2 + 1;
        params.bystanderCloseDelay = 0;
        profits = sandwich();
        logCSVRow(profits);

        // Short: Close Half Term
        // Everlong: Close Half Term
        // Bystander: Close Full Term
        params.timeToCloseShort = POSITION_DURATION / 2;
        params.timeToCloseEverlong = 0;
        params.bystanderCloseDelay = POSITION_DURATION / 2 + 1;
        profits = sandwich();
        logCSVRow(profits);

        // Short: Close Full Term
        // Everlong: Close Full Term
        // Bystander: Close Full Term
        params.timeToCloseShort = POSITION_DURATION + 1;
        params.timeToCloseEverlong = 0;
        params.bystanderCloseDelay = 0;
        profits = sandwich();
        logCSVRow(profits);
    }

    function logCSVRow(string memory _profits) internal view {
        console.log(
            string(
                abi.encodePacked(
                    INITIAL_CONTRIBUTION.toString(18),
                    ",",
                    FIXED_RATE.toString(18),
                    ",",
                    VARIABLE_RATE.toString(18),
                    ",",
                    hyperdrive.getPoolConfig().timeStretch.toString(18),
                    ",",
                    hyperdrive.getPoolConfig().fees.curve.toString(18),
                    ",",
                    hyperdrive.getPoolConfig().fees.flat.toString(18),
                    ",",
                    paramsToCSV(),
                    ",",
                    _profits,
                    ",",
                    ERC20Mintable(everlong.asset())
                        .balanceOf(address(everlong))
                        .toString(18)
                )
            )
        );
    }

    function paramsToCSV() internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    params.initialDeposit.toString(18),
                    ",",
                    params.bystanderDeposit.toString(18),
                    ",",
                    params.sandwichShort.toString(18),
                    ",",
                    params.sandwichDeposit.toString(18),
                    ",",
                    (
                        params.timeToCloseShort > 0
                            ? params.timeToCloseShort.divDown(POSITION_DURATION)
                            : 0
                    ).toString(18),
                    ",",
                    (
                        params.timeToCloseEverlong > 0
                            ? params.timeToCloseEverlong.divDown(
                                POSITION_DURATION
                            )
                            : 0
                    ).toString(18),
                    ",",
                    (
                        params.bystanderCloseDelay > 0
                            ? params.bystanderCloseDelay.divDown(
                                POSITION_DURATION
                            )
                            : 0
                    ).toString(18)
                )
            );
    }

    function clearBalances() internal {
        // Clear initial depositor balance
        vm.startPrank(celine);
        ERC20Mintable(everlong.asset()).burn(
            ERC20Mintable(everlong.asset()).balanceOf(celine)
        );
        vm.stopPrank();
        // Clear attacker balance
        vm.startPrank(bob);
        ERC20Mintable(everlong.asset()).burn(
            ERC20Mintable(everlong.asset()).balanceOf(bob)
        );
        vm.stopPrank();
        // Clear bystander balance
        vm.startPrank(alice);
        ERC20Mintable(everlong.asset()).burn(
            ERC20Mintable(everlong.asset()).balanceOf(alice)
        );
        vm.stopPrank();
    }

    /// @dev Order of operations:
    ///      1. Celine makes an initial deposit into Everlong.
    ///      2. Alice (bystander) makes a deposit.
    ///      3. Bob (attacker) opens a short on Hyperdrive.
    ///      4. Bob (attacker) makes a deposit.
    ///      5. Bob (attacker) closes short on Hyperdrive.
    ///      6. Bob (attacker) redeems from Everlong.
    ///      7. Alice (bystander) redeems from Everlong.
    ///      8. Celine redeems from Everlong.
    function sandwich() internal returns (string memory) {
        // Deploy Everlong.
        deployEverlong();

        // Clear all balances
        clearBalances();

        // Adjust short amount
        if (params.sandwichShort > 0) {
            uint256 maxShort = hyperdrive.calculateMaxShort();
            if (params.sandwichShort > maxShort) {
                params.sandwichShort = maxShort;
            }
        }

        // Initial deposit is made into everlong.
        depositEverlong(params.initialDeposit, celine);

        // Innocent bystander deposits into everlong.
        depositEverlong(params.bystanderDeposit, alice);

        // Attacker opens a short on hyperdrive.
        uint256 bobShortMaturityTime;
        uint256 bobShortAmount;
        if (params.sandwichShort > 0) {
            (bobShortMaturityTime, bobShortAmount) = openShort(
                bob,
                params.sandwichShort,
                true
            );
        }

        // Attacker deposits into everlong.
        uint256 bobEverlongShares = depositEverlong(
            params.sandwichDeposit,
            bob
        );

        if (params.timeToCloseShort > 0) {
            advanceTimeWithCheckpointsAndRebalancing(params.timeToCloseShort);
            if (everlong.canRebalance()) {
                everlong.rebalance();
            }
        }

        // Attacker closes short on hyperdrive.
        uint256 bobProceedsShort;
        if (params.sandwichShort > 0) {
            bobProceedsShort = closeShort(
                bob,
                bobShortMaturityTime,
                params.sandwichShort,
                true
            );
        }

        if (params.timeToCloseEverlong > 0) {
            advanceTimeWithCheckpointsAndRebalancing(
                params.timeToCloseEverlong
            );
            if (everlong.canRebalance()) {
                everlong.rebalance();
            }
        }

        // Attacker redeems from everlong.
        // uint256 bobProceedsEverlong = redeemEverlong(bobEverlongShares, bob);
        redeemEverlong(bobEverlongShares, bob);
        if (everlong.canRebalance()) {
            everlong.rebalance();
        }

        if (params.bystanderCloseDelay > 0) {
            advanceTimeWithCheckpointsAndRebalancing(
                params.bystanderCloseDelay
            );
            if (everlong.canRebalance()) {
                everlong.rebalance();
            }
        }

        return
            string(
                abi.encodePacked(
                    bobShortAmount.toString(18),
                    ",",
                    ERC20Mintable(everlong.asset()).balanceOf(bob).toString(18),
                    ",",
                    ERC20Mintable(everlong.asset()).balanceOf(alice).toString(
                        18
                    ),
                    ",",
                    ERC20Mintable(everlong.asset()).balanceOf(celine).toString(
                        18
                    )
                )
            );
    }
}
