// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { EverlongTest } from "../harnesses/EverlongTest.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { HyperdriveExecutionLibrary } from "../../contracts/libraries/HyperdriveExecution.sol";

contract TestVaultSharePrice is EverlongTest {
    using FixedPointMath for uint256;
    using Lib for *;
    using HyperdriveUtils for *;
    using HyperdriveExecutionLibrary for *;

    function test_vault_share_price_deposit_redeem() external {
        // Skip this test unless disabled manually.
        vm.skip(true);

        deployEverlong();

        // Alice makes a deposit.
        uint256 aliceDeposit = 10_000e18;
        uint256 aliceShares = depositEverlong(aliceDeposit, alice);

        console.log(
            "Vault Share Price 1: %e",
            everlong.totalAssets().divDown(everlong.totalSupply())
        );

        // Bob makes a deposit.
        uint256 bobDeposit = 10_000e18;
        uint256 bobShares = depositEverlong(bobDeposit, bob);
        console.log(
            "Vault Share Price 2: %e",
            everlong.totalAssets().divDown(everlong.totalSupply())
        );

        // Celine makes a deposit.
        uint256 celineDeposit = 10_000e18;
        uint256 celineShares = depositEverlong(celineDeposit, celine);
        console.log(
            "Vault Share Price 3: %e",
            everlong.totalAssets().divDown(everlong.totalSupply())
        );

        // Bob redeems.
        redeemEverlong(bobShares, bob);
        console.log(
            "Vault Share Price 4: %e",
            everlong.totalAssets().divDown(everlong.totalSupply())
        );

        // Celine redeems.
        redeemEverlong(celineShares, celine);
        console.log(
            "Vault Share Price 5: %e",
            everlong.totalAssets().divDown(everlong.totalSupply())
        );

        console.log(
            "Everlong Balance: %e",
            IERC20(everlong.asset()).balanceOf(address(everlong))
        );
    }
}
