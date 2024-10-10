// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
import { Everlong } from "./Everlong.sol";
import { IEverlong } from "./interfaces/IEverlong.sol";
import { EVERLONG_KIND, EVERLONG_VERSION, ONE } from "./libraries/Constants.sol";
import { HyperdriveExecutionLibrary } from "./libraries/HyperdriveExecution.sol";
import { Portfolio } from "./libraries/Portfolio.sol";

/// @author DELV
/// @title EverlongUpdateOnRebalance
/// @notice Everlong instance that only updates totalAssets only on rebalance.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract EverlongUpdateOnRebalance is Everlong {
    using FixedPointMath for uint256;
    using HyperdriveExecutionLibrary for IHyperdrive;
    using Portfolio for Portfolio.State;
    using SafeCast for *;
    using SafeERC20 for ERC20;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Storage                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    // ─────────────────────────── State ────────────────────────

    uint256 internal portfolioValue;
    // ╭─────────────────────────────────────────────────────────╮
    // │ Constructor                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Initial configuration paramters for EverlongERC4626.
    /// @param __name Name of the ERC20 token managed by Everlong.
    /// @param __symbol Symbol of the ERC20 token managed by Everlong.
    /// @param __decimals Decimals of the Everlong token and Hyperdrive token.
    /// @param _hyperdrive Address of the Hyperdrive instance.
    /// @param _asBase Whether to use the base or shares token from Hyperdrive.
    /// @param _targetIdleLiquidityPercentage Target percentage of funds to
    ///        keep idle.
    /// @param _maxIdleLiquidityPercentage Max percentage of funds to keep
    ///        idle.
    constructor(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        address _hyperdrive,
        bool _asBase,
        uint256 _targetIdleLiquidityPercentage,
        uint256 _maxIdleLiquidityPercentage
    )
        Everlong(
            __name,
            __symbol,
            __decimals,
            _hyperdrive,
            _asBase,
            _targetIdleLiquidityPercentage,
            _maxIdleLiquidityPercentage
        )
    {}

    // ╭─────────────────────────────────────────────────────────╮
    // │ ERC4626                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Calculate the total amount of assets controlled by everlong.
    /// @notice To do this efficiently, the weighted average maturity is used.
    /// @dev Underestimates the actual value by overestimating the average
    ///      maturity of the portfolio.
    /// @return Total amount of assets controlled by Everlong.
    function totalAssets() public view virtual override returns (uint256) {
        // If everlong holds no bonds, return the balance.
        uint256 balance = ERC20(_asset).balanceOf(address(this));
        if (_portfolio.totalBonds == 0) {
            return balance;
        }
        //
        // return portfolioValue;

        return _calculatePortfolioValue();
    }

    function previewRedeem(
        uint256 _shares
    ) public view override returns (uint256 assets) {
        assets = convertToAssets(_shares);
        uint256 balance = ERC20(_asset).balanceOf(address(this));
        if (assets < balance) {
            return assets;
        }
        assets -= _accountForImmatureLosses(assets - balance);
    }

    /// @dev Attempt rebalancing after a deposit if idle is above max.
    function _afterDeposit(uint256, uint256) internal virtual override {
        if (ERC20(_asset).balanceOf(address(this)) > maxIdleLiquidity()) {
            rebalance();
        }
    }

    /// @dev Frees sufficient assets for a withdrawal by closing positions.
    /// @param _assets Amount of assets owed to the withdrawer.
    function _beforeWithdraw(
        uint256 _assets,
        uint256
    ) internal virtual override {
        // If we have enough balance to service the withdrawal, no need to
        // close positions.
        uint256 balance = ERC20(_asset).balanceOf(address(this));
        if (_assets <= balance) {
            return;
        }

        // Close more positions until sufficient idle to process withdrawal.
        _closePositions(_assets - balance);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Rebalancing                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Rebalance the everlong portfolio by closing mature positions
    ///         and using the proceeds over target idle to open new positions.
    function rebalance() public virtual override {
        // Early return if no rebalancing is needed.
        if (!canRebalance()) {
            return;
        }

        // Close matured positions.
        _closeMaturedPositions();

        // Amount to spend is the current balance less the target idle.
        uint256 toSpend = ERC20(_asset).balanceOf(address(this)) -
            targetIdleLiquidity();

        // Open a new position. Leave an extra wei for the approval to keep
        // the slot warm.
        ERC20(_asset).forceApprove(address(hyperdrive), toSpend + 1);
        (uint256 maturityTime, uint256 bondAmount) = IHyperdrive(hyperdrive)
            .openLong(asBase, toSpend, "");

        // Account for the new position in the portfolio.
        _portfolio.handleOpenPosition(maturityTime, bondAmount);

        _updatePortfolioValue();

        emit Rebalanced();
    }

    function _updatePortfolioValue() internal {
        portfolioValue = _calculatePortfolioValue();
    }

    function _calculatePortfolioValue() internal view returns (uint256) {
        return
            ERC20(_asset).balanceOf(address(this)) +
            _calculateViaSpotPrice(
                IHyperdrive(hyperdrive).getCheckpointIdUp(
                    _portfolio.avgMaturityTime
                ),
                _portfolio.totalBonds
            );
    }

    function _calculateViaSpotPrice(
        uint256 _maturity,
        uint256 _bonds
    ) internal view returns (uint256) {
        if (_bonds == 0) {
            return 0;
        }
        uint256 p = IHyperdrive(hyperdrive)
            .getCheckpointDown(block.timestamp)
            .weightedSpotPrice;
        uint256 adjusted = IHyperdrive(hyperdrive).previewCloseLong(
            asBase,
            IEverlong.Position({
                maturityTime: uint128(_maturity),
                bondAmount: uint128(_bonds)
            }),
            p,
            ""
        );
        return adjusted;
    }

    function _calculateViaSpotPrice2(
        uint256 _maturity,
        uint256 _bonds
    ) internal view returns (uint256) {
        if (_bonds == 0) {
            return 0;
        }
        uint256 t = IHyperdrive(hyperdrive).normalizedTimeRemaining(_maturity);
        uint256 p = IHyperdrive(hyperdrive)
            .getCheckpointDown(block.timestamp)
            .weightedSpotPrice;
        return (p.mulUp(t) + (1 - t)).mulUp(_bonds);
    }

    function _accountForImmatureLosses(
        uint256 _assets
    ) internal view returns (uint256 losses) {
        uint256 output;
        uint256 proceeds;
        uint256 estimatedProceeds;
        IEverlong.Position memory position;
        uint256 i;
        uint256 count = _portfolio.positionCount();
        while (i < count && output < _assets) {
            position = _portfolio.at(i);
            proceeds = IHyperdrive(hyperdrive).previewCloseLong(
                asBase,
                position,
                ""
            );
            estimatedProceeds = _calculateViaSpotPrice(
                position.maturityTime,
                position.bondAmount
            );
            output += estimatedProceeds;
            if (proceeds < estimatedProceeds) {
                losses += estimatedProceeds - proceeds;
            }
            i++;
        }
        losses = losses.mulDivUp(_assets, output);
        return losses;
    }
}
