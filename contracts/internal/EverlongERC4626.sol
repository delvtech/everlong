// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { HyperdriveMath } from "hyperdrive/contracts/src/libraries/HyperdriveMath.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { ERC4626 } from "solady/tokens/ERC4626.sol";
import { EverlongBase } from "./EverlongBase.sol";
import { Positions } from "../libraries/Positions.sol";
import { Position } from "../types/Position.sol";

/// @author DELV
/// @title EverlongERC4626
/// @notice Everlong ERC4626 implementation.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongERC4626 is ERC4626, EverlongBase {
    using FixedPointMath for uint256;
    using Positions for Positions.PositionQueue;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc ERC4626
    function redeem(
        uint256 shares,
        address to,
        address owner
    ) public override returns (uint256 assets) {
        // Execute the original ERC4626 `redeem(...)` logic which includes
        // calling the `_beforeWithdraw(...)` hook to ensure there is
        // sufficient idle liquidity to service the redemption.
        assets = super.redeem(shares, to, owner);

        // Rebalance Everlong's positions by closing any matured positions
        // and reinvesting the proceeds in new bonds.
        _rebalance();
    }

    // TODO: Implement.
    /// @inheritdoc ERC4626
    function mint(uint256, address) public override returns (uint256 assets) {
        revert("mint not implemented, please use deposit");
    }

    // TODO: Implement.
    /// @inheritdoc ERC4626
    function withdraw(
        uint256,
        address,
        address
    ) public override returns (uint256 shares) {
        revert("withdraw not implemented, please use redeem");
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Overrides                                               │
    // ╰─────────────────────────────────────────────────────────╯

    // TODO: Actually estimate this based on current position contents.
    //       Currently, this is obtained from tracking deposits - withdrawals
    //       which results in Everlong taking all profit and users receiving
    //       exactly what they put in.
    /// @notice Returns the total value of assets managed by Everlong.
    /// @return Total managed asset value.
    function totalAssets() public view override returns (uint256) {
        return
            IERC20(_asset).balanceOf(address(this)) +
            estimateLongProceeds(
                _positions._quantity,
                HyperdriveUtils.calculateTimeRemaining(
                    IHyperdrive(_hyperdrive),
                    _positions._avgMaturity
                ),
                _positions._avgVaultSharePrice,
                IHyperdrive(_hyperdrive).getPoolInfo().vaultSharePrice
            ).mulUp(1e18 - maxSlippage);
    }

    // FIXME: Add Comment
    // function previewRedeem(
    //     uint256 shares
    // ) public view override returns (uint256 assets) {
    //     // TODO: Fix off-by-one error
    //     assets = convertToAssets(shares) - 1;
    //
    //     uint256 idle = IERC20(_asset).balanceOf(address(this));
    //     if (idle >= assets) return assets;
    //
    //     // Close immature positions from oldest to newest until idle is
    //     // above the target.
    //     uint256 positionCount = _positions.count();
    //     Position memory position;
    //     uint256 i = 0;
    //     while (idle < assets) {
    //         position = _positions.at(i);
    //
    //         uint256 estimatedProceeds = estimateLongProceeds(
    //             position.quantity,
    //             HyperdriveUtils.calculateTimeRemaining(
    //                 IHyperdrive(_hyperdrive),
    //                 position.maturity
    //             ),
    //             position.vaultSharePrice,
    //             IHyperdrive(_hyperdrive).getPoolInfo().vaultSharePrice
    //         );
    //
    //         console.log("quantity: %s", position.quantity);
    //         console.log("vsp: %s", position.vaultSharePrice);
    //         console.log("maturity: %s", position.maturity);
    //
    //         uint256 avgProceeds = estimateLongProceeds(
    //             position.quantity,
    //             HyperdriveUtils.calculateTimeRemaining(
    //                 IHyperdrive(_hyperdrive),
    //                 _positions._avgMaturity
    //             ),
    //             _positions._avgVaultSharePrice,
    //             IHyperdrive(_hyperdrive).getPoolInfo().vaultSharePrice
    //         );
    //
    //         console.log("estimated: %s", estimatedProceeds);
    //         console.log("avg: %s", avgProceeds);
    //         console.log("diff: %s", avgProceeds - estimatedProceeds);
    //
    //         if (estimatedProceeds < avgProceeds) {
    //             assets -= avgProceeds - estimatedProceeds;
    //         }
    //         idle += estimatedProceeds;
    //
    //         i++;
    //     }
    //
    //     return assets;
    // }

    /// @inheritdoc ERC4626
    function maxDeposit(
        address
    ) public view override returns (uint256 maxAssets) {
        maxAssets = HyperdriveUtils.calculateMaxLong(IHyperdrive(_hyperdrive));
    }

    /// @dev Decrement the virtual assets and close sufficient positions to
    ///      service the withdrawal.
    /// @param _assets Amount of assets owed to the withdrawer.
    function _beforeWithdraw(
        uint256 _assets,
        uint256
    ) internal virtual override {
        // TODO: Re-evaluate this accounting logic after discussing
        //       withdrawal shares and whether to close immature positions.

        // Close remaining positions until Everlong's balance is enough to
        // meet the withdrawal.
        _increaseIdle(_assets);
    }

    /// @dev Increment the virtual assets and rebalance positions to use
    ///      the newly-deposited liquidity.
    /// @param _assets Amount of assets deposited.
    function _afterDeposit(uint256 _assets, uint256) internal virtual override {
        // TODO: Re-evaluate this accounting logic after discussing
        //       withdrawal shares and whether to close immature positions.
        //
        // Rebalance the Everlong portfolio.
        // _rebalance();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Internal                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Returns whether virtual shares will be used to mitigate the inflation attack.
    /// @dev See: https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3706
    /// @dev MUST NOT revert.
    function _useVirtualShares() internal view virtual override returns (bool) {
        return useVirtualShares;
    }

    /// @dev Returns the number of decimals of the underlying asset.
    /// @dev MUST NOT revert.
    function _underlyingDecimals()
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _decimals;
    }

    /// @dev A non-zero value used to make the inflation attack even more unfeasible.
    /// @dev MUST NOT revert.
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return decimalsOffset;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Address of the token to use for deposits/withdrawals.
    /// @dev MUST be an ERC20 token contract.
    /// @return Asset address.
    function asset() public view virtual override returns (address) {
        return _asset;
    }

    /// @notice Returns the name of the Everlong token.
    /// @return Everlong token name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the Everlong token.
    /// @return Everlong token symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
}
