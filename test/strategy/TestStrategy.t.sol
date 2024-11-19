// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlongStrategy } from "../../contracts/interfaces/IEverlongStrategy.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";

contract TestStrategy is EverlongTest {
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;
    using HyperdriveExecutionLibrary for *;

    /// @dev Tests that the gas cost for closing the maximum amount of matured
    ///      positions does not exceed the block gas limit.
    function test_tend_max_matured_positions() external {
        // Calculate the maximum amount of positions possible with the current
        // position and checkpoint durations.
        uint256 maxPositionCount = POSITION_DURATION / CHECKPOINT_DURATION;

        // Loop through and make deposits each checkpoint interval.
        // Keep track of shares for the redeem call later which will force
        // the closure of the matured positions.
        uint256 shares;
        uint256 spent;
        for (uint256 i; i < maxPositionCount; i++) {
            spent += MINIMUM_TRANSACTION_AMOUNT * 200;
            shares += depositVault(
                MINIMUM_TRANSACTION_AMOUNT * 200,
                alice,
                true
            );
            advanceTimeWithCheckpoints(CHECKPOINT_DURATION);
            if (i != 0 && i % 7 == 0) {
                report();
            }
        }

        // Ensure Everlong has the maximum amount of positions possible.
        assertEq(strategy.positionCount(), maxPositionCount);

        // Advance time so that all positions are mature.
        advanceTimeWithCheckpoints(POSITION_DURATION);

        rebalance();
        report();

        console.log("Current APR: %e", aprOracle.getCurrentApr(address(vault)));
        console.log("Profit Unlock Rate: %e", strategy.profitUnlockingRate());
        // console.log(
        //     "Profit Unlock Time: %e",
        //     (vault.fullProfitUnlockDate() - block.timestamp) / 1 days
        // );

        // Track the gas cost for the redemption.
        uint256 gasUsed = gasleft();
        redeemVault(shares, alice);
        gasUsed -= gasleft();

        console.log(
            "Profit: %e",
            ERC20Mintable(strategy.asset()).balanceOf(alice) - spent
        );

        // Ensure the gas cost of the redemption is less than the block gas
        // limit.
        uint256 blockGasLimit = 30_000_000;
        assertLt(gasUsed, blockGasLimit);
    }
}
