// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";

contract TestVaultSharePrice is EverlongTest {
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;
    using HyperdriveExecutionLibrary for *;

    function test_vault_share_price_deposit_redeem() external {
        // Skip this test unless disabled manually.
        // vm.skip(true);

        deployEverlong();

        // Alice makes a deposit.
        uint256 aliceDeposit = 10_000e18;
        uint256 aliceShares = depositStrategy(aliceDeposit, alice);

        console.log(
            "Vault Share Price 1: %e",
            vault.totalAssets().divDown(vault.totalSupply())
        );

        // Bob makes a deposit.
        uint256 bobDeposit = 10_000e18;
        uint256 bobShares = depositStrategy(bobDeposit, bob);
        console.log(
            "Vault Share Price 2: %e",
            vault.totalAssets().divDown(vault.totalSupply())
        );

        // Celine makes a deposit.
        uint256 celineDeposit = 10_000e18;
        uint256 celineShares = depositStrategy(celineDeposit, celine, true);
        console.log(
            "Vault Share Price 3: %e",
            vault.totalAssets().divDown(vault.totalSupply())
        );

        // Bob redeems.
        redeemStrategy(bobShares, bob);
        console.log(
            "Vault Share Price 4: %e",
            vault.totalAssets().divDown(vault.totalSupply())
        );

        // Celine redeems.
        redeemStrategy(celineShares, celine);
        console.log(
            "Vault Share Price 5: %e",
            vault.totalAssets().divDown(vault.totalSupply())
        );

        console.log(
            "Everlong Balance: %e",
            IERC20(vault.asset()).balanceOf(address(vault))
        );
    }
}
