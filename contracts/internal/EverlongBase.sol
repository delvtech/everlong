// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { HyperdriveMath } from "hyperdrive/contracts/src/libraries/HyperdriveMath.sol";
import { IEverlongEvents } from "../interfaces/IEverlongEvents.sol";
import { EverlongStorage } from "./EverlongStorage.sol";

// TODO: Reassess whether centralized configuration management makes sense.
//       https://github.com/delvtech/everlong/pull/2#discussion_r1703799747
/// @author DELV
/// @title EverlongBase
/// @notice Base contract for Everlong.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongBase is EverlongStorage, IEverlongEvents {
    using FixedPointMath for uint256;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Rebalances the Everlong bond portfolio if needed.
    function _rebalance() internal virtual;

    /// @dev Close positions until sufficient idle liquidity is held.
    /// @dev Reverts if the target is unreachable.
    /// @param _target Target amount of idle liquidity to reach.
    /// @return idle Amount of idle after the increase.
    function _increaseIdle(
        uint256 _target
    ) internal virtual returns (uint256 idle);

    function estimateLongProceeds(
        uint256 bondAmount,
        uint256 normalizedTimeRemaining,
        uint256 openVaultSharePrice,
        uint256 closeVaultSharePrice
    ) internal view returns (uint256) {
        IHyperdrive.PoolInfo memory poolInfo = IHyperdrive(_hyperdrive)
            .getPoolInfo();
        IHyperdrive.PoolConfig memory poolConfig = IHyperdrive(_hyperdrive)
            .getPoolConfig();
        (, , uint256 shareProceeds) = HyperdriveMath.calculateCloseLong(
            HyperdriveMath.calculateEffectiveShareReserves(
                poolInfo.shareReserves,
                poolInfo.shareAdjustment
            ),
            poolInfo.bondReserves,
            bondAmount,
            normalizedTimeRemaining,
            poolConfig.timeStretch,
            poolInfo.vaultSharePrice,
            poolConfig.initialVaultSharePrice
        );
        if (closeVaultSharePrice < openVaultSharePrice) {
            shareProceeds = shareProceeds.mulDivDown(
                closeVaultSharePrice,
                openVaultSharePrice
            );
        }
        return shareProceeds.mulDivDown(poolInfo.vaultSharePrice, 1e18);
    }
}
