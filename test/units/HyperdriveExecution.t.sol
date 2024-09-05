// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { ERC20Mintable } from "hyperdrive/contracts/test/ERC20Mintable.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests the functionality around opening, closing, and valuing hyperdrive positions.
contract TestHyperdriveExecution is EverlongTest {
    using HyperdriveExecutionLibrary for IHyperdrive;
    using SafeCast for *;

    Portfolio.State public portfolio;

    function test_previewCloseLong_portfolio_averages() external {
        // Initialize the market
        uint256 apr = 0.05e18;
        deploy(alice, apr, 1.5e18, 0.01e18, 0.0005e18, 0.15e18, 0.03e18);
        uint256 contribution = 500_000_000e18;
        initialize(alice, apr, contribution);
        vm.startPrank(deployer);
        deploy();
        vm.stopPrank();
        advanceTime(POSITION_DURATION * 2, 0.10e18);

        // Bob makes the first deposit.
        uint256 bobAmount = 100e18;
        mintApproveEverlongBaseAsset(bob, bobAmount);
        vm.startPrank(bob);
        uint256 bobShares = everlong.deposit(bobAmount, bob);
        everlong.rebalance();

        // Advance time 1/6th of the way through the term.
        advanceTime(POSITION_DURATION / 6, 0.05e18);

        // Celine makes the second deposit.
        uint256 celineAmount = 10e18;
        mintApproveEverlongBaseAsset(celine, celineAmount);
        vm.startPrank(celine);
        uint256 celineShares = everlong.deposit(celineAmount, celine);
        everlong.rebalance();

        // Advance time 1/6th of the way through the term.
        advanceTime(POSITION_DURATION / 6, 0.05e18);

        // Celine makes the second deposit.
        uint256 danAmount = 5e18;
        mintApproveEverlongBaseAsset(dan, danAmount);
        vm.startPrank(dan);
        uint256 danShares = everlong.deposit(danAmount, dan);
        everlong.rebalance();

        // Advance time 1/6th of the way through the term.
        advanceTime(POSITION_DURATION / 6, 0.05e18);

        // Estimate the portfolio value.
        uint256 estimatedOutput = hyperdrive.previewCloseLong(
            IEverlong.Position({
                maturityTime: hyperdrive
                    .getNearestCheckpointIdUp(everlong.avgMaturityTime())
                    .toUint128(),
                bondAmount: everlong.totalBonds(),
                vaultSharePrice: everlong.avgVaultSharePrice()
            }),
            HyperdriveExecutionLibrary.CloseLongParams({
                asBase: true,
                maxSlippage: 1e18
            })
        );

        console.log("estimate output: %s", estimatedOutput);

        // Get the previewRedeem output.
        uint256 redeemOutput = everlong.previewRedeem(
            bobShares + celineShares + danShares
        );
        console.log("redeem output:   %s", redeemOutput);
    }
}
