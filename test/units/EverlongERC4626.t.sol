// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// solhint-disable-next-line no-console, no-unused-import
import { console2 as console } from "forge-std/console2.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";

/// @dev Tests EverlongERC4626 functionality.
/// @dev Functions not overridden by Everlong are assumed to be functional.
contract TestEverlongERC4626 is EverlongTest {
    /// @dev Performs a redemption while ensuring the preview amount at most
    ///      equals the actual output and is within tolerance.
    /// @param _shares Amount of shares to redeem.
    /// @param _redeemer Address of the share holder.
    /// @return assets Assets sent to _redeemer from the redemption.
    function assertRedemption(
        uint256 _shares,
        address _redeemer
    ) public returns (uint256 assets) {
        uint256 preview = vault.previewRedeem(_shares);
        vm.startPrank(_redeemer);
        assets = vault.redeem(_shares, _redeemer, _redeemer);
        vm.stopPrank();
        assertLe(preview, assets);
        assertApproxEqAbs(preview, assets, 1e9);
    }

    /// @dev Tests that previewRedeem does not overestimate proceeds for a
    ///      single shareholder immediately redeeming all their shares.
    function test_previewRedeem_single_instant_full() external {
        // Deposit into everlong.
        uint256 amount = 250e18;
        uint256 shares = depositStrategy(amount, alice, true);

        // Ensure that previewRedeem output is at most equal to actual output
        // and within margins.
        assertRedemption(shares, alice);
    }

    /// @dev Tests that previewRedeem does not overestimate proceeds for a
    ///      single shareholder immediately redeeming part of their shares.
    function test_previewRedeem_single_instant_partial() external {
        // Deposit into everlong.
        uint256 amount = 250e18;
        uint256 shares = depositStrategy(amount, alice, true);

        // Ensure that previewRedeem output is at most equal to actual output
        // and within margins.
        assertRedemption(shares / 2, alice);
    }

    /// @dev Tests that previewRedeem does not overestimate proceeds for a
    ///      single shareholder waiting half the position duration and
    ///      redeeming all their shares.
    function test_previewRedeem_single_unmatured_full() external {
        // Deposit into everlong.
        uint256 amount = 250e18;
        uint256 shares = depositStrategy(amount, alice, true);

        // Fast forward to halfway through maturity.
        advanceTimeWithCheckpointsAndRebalancing(POSITION_DURATION / 2);

        // Ensure that previewRedeem output is at most equal to actual output
        // and within margins.
        assertRedemption(shares, alice);
    }

    /// @dev Tests that previewRedeem does not overestimate proceeds for a
    ///      single shareholder waiting half the position duration and
    ///      redeeming some of their shares.
    function test_previewRedeem_single_unmatured_partial() external {
        // Deposit into everlong.
        uint256 amount = 250e18;
        uint256 shares = depositStrategy(amount, alice, true);

        // Fast forward to halfway through maturity.
        advanceTimeWithCheckpointsAndRebalancing(POSITION_DURATION / 2);

        // Ensure that previewRedeem output is at most equal to actual output
        // and within margins.
        assertRedemption(shares / 3, alice);
    }

    // FIXME: Convert into fuzz test
    function test_previewWithdraw_previewRedeem_parity() external {
        uint256 aliceDeposit = 10_0000e18;
        uint256 aliceShares = depositStrategy(aliceDeposit, alice);

        uint256 bobDeposit = 5_000e18;
        uint256 bobShares = depositStrategy(bobDeposit, bob);

        redeemStrategy(bobShares, bob);

        openShort(celine, 30_000e18);

        uint256 withdrawalShares = aliceShares / 10;
        uint256 previewRedeemResult = vault.previewRedeem(withdrawalShares);
        uint256 previewWithdrawResult = vault.previewWithdraw(
            previewRedeemResult
        );

        assertGe(previewWithdrawResult, withdrawalShares);
        assertApproxEqRel(withdrawalShares, previewWithdrawResult, 0.0001e18);
    }
}
