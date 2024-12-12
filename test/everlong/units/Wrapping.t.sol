// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { IERC20, IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { IERC20Wrappable } from "../../../contracts/interfaces/IERC20Wrappable.sol";
import { IEverlongStrategy } from "../../../contracts/interfaces/IEverlongStrategy.sol";
import { EVERLONG_STRATEGY_KIND, EVERLONG_VERSION } from "../../../contracts/libraries/Constants.sol";
import { EverlongTest } from "../EverlongTest.sol";

/// @dev Tests wrapping functionality for rebasing tokens.
contract TestWrapping is EverlongTest {
    using FixedPointMath for *;

    /// @dev The StETH token address.
    address internal constant STETH =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    /// @dev The WStETH address.
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    // @dev StETH hyperdrive address.
    address constant STETH_HYPERDRIVE =
        0xd7e470043241C10970953Bd8374ee6238e77D735;

    /// @dev The StETH whale address.
    address internal constant STETH_WHALE =
        0x1982b2F5814301d4e9a8b0201555376e62F82428;

    /// @dev Mint some WStETH to the specified account.
    function mint(address _to, uint256 _amount) internal {
        vm.startPrank(STETH_WHALE);
        IERC20(STETH).approve(WSTETH, type(uint256).max);
        IERC20Wrappable(WSTETH).wrap(
            IEverlongStrategy(address(strategy))
                .convertToUnwrapped(_amount)
                .mulUp(1.001e18)
        );
        IERC20Wrappable(WSTETH).transfer(_to, _amount);
        vm.stopPrank();
    }

    /// @dev Deposit the specified amount of wrapped assets into the vault.
    function depositWrapped(
        address _from,
        uint256 _amount
    ) internal returns (uint256 shares) {
        mint(_from, _amount);
        vm.startPrank(_from);
        IERC20Wrappable(WSTETH).approve(address(vault), _amount + 1);
        shares = vault.deposit(_amount, _from);
        vm.stopPrank();
    }

    /// @dev Redeem the specified amount of shares from the vault.
    function redeemWrapped(
        address _from,
        uint256 _shares
    ) internal returns (uint256 assets) {
        vm.startPrank(_from);

        assets = vault.redeem(_shares, _from, _from);
        vm.stopPrank();
    }

    function setUp() public virtual override {
        super.setUp();

        AS_BASE = false;
        IS_WRAPPED = true;
        WRAPPED_ASSET = WSTETH;
        hyperdrive = IHyperdrive(STETH_HYPERDRIVE);

        setUpEverlongStrategy();
        setUpEverlongVault();
    }

    /// @dev Ensure the deposit functions work as expected.
    function test_deposit() external {
        // Alice deposits into the vault.
        uint256 depositAmount = 100e18;
        uint256 aliceShares = depositWrapped(alice, depositAmount);

        // Alice should have non-zero share amounts.
        assertGt(aliceShares, 0);

        // FIXME: The call below fails with `ALLOWANCE_EXCEEDED` despite the
        //        proper approval being in place...
        //
        // Call update_debt and tend.
        rebalance();
    }
}
