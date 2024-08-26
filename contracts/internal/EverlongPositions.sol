// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlong } from "../interfaces/IEverlong.sol";
import { IEverlongPositions } from "../interfaces/IEverlongPositions.sol";
import { Positions } from "../libraries/Positions.sol";
import { Position } from "../types/Position.sol";
import { EverlongBase } from "./EverlongBase.sol";

/// @author DELV
/// @title EverlongPositions
/// @notice Everlong bond position management.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongPositions is EverlongBase, IEverlongPositions {
    using Positions for Positions.PositionQueue;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongPositions
    function rebalance() external {
        _rebalance();
    }

    /// @dev Rebalances the Everlong bond portfolio if needed.
    function _rebalance() internal override {
        // Close all mature positions (if present) so that the proceeds can be
        // used to purchase longs.
        if (hasMaturedPositions()) {
            _closeMaturedPositions();
        }

        // Spend Everlong's excess idle liquidity (if sufficient) on opening a long.
        if (hasSufficientIdle()) {
            _spendIdle();
        }

        // Emit the `Rebalanced()` event.
        emit Rebalanced();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Virtual                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    // TODO: Implement idle liquidity and possibly remove.
    /// @dev Calculates the amount of idle liquidity that can be spent opening longs.
    /// @dev Can be overridden by child contracts.
    /// @return Amount of idle liquidity that can be spent opening longs.
    function _idle() internal view virtual returns (uint256) {
        // Return the current balance of the contract.
        return IERC20(_asset).balanceOf(address(this));
    }

    // TODO: Come up with a safer value or remove.
    /// @dev Calculates the minimum `openLong` output from Hyperdrive
    ///       given the amount of capital being spend.
    /// @dev Can be overridden by child contracts.
    /// @param _amount Amount of capital provided for `openLong`.
    /// @return Minimum number of bonds to receive from `openLong`.
    function _minOpenLongOutput(
        uint256 _amount
    ) internal view virtual returns (uint256) {
        return 0;
    }

    // TODO: Come up with a safer value or remove.
    /// @dev Calculates the minimum vault share price at which to
    ///      open the long.
    /// @dev Can be overridden by child contracts.
    /// @param _amount Amount of capital provided for `openLong`.
    /// @return minimum vault share price for `openLong`.
    function _minVaultSharePrice(
        uint256 _amount
    ) internal view virtual returns (uint256) {
        return 0;
    }

    // TODO: Come up with a safer value or remove.
    /// @dev Calculates the minimum proceeds Everlong will accept for
    ///      closing the long.
    /// @dev Can be overridden by child contracts.
    /// @param _maturityTime Maturity time of the long to close.
    /// @param _bondAmount Amount of bonds to close.
    function _minCloseLongOutput(
        uint256 _maturityTime,
        uint256 _bondAmount
    ) internal view returns (uint256) {
        return 0;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Opening (Internal)                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Spend the excess idle liquidity for the Everlong contract.
    /// @dev Can be overridden by implementing contracts to configure
    ///      how much idle to spend and how it is spent.
    function _spendIdle() internal {
        // PERF: Should directly access storage slot rather than retrieving
        //       entire PoolInfo.
        //
        // Record the vault share price prior to opening longs for profit/loss
        // calculations.
        uint256 vaultSharePrice = IHyperdrive(_hyperdrive)
            .getPoolInfo()
            .vaultSharePrice;

        // Open the long position with the available excess liquidity.
        // TODO: Worry about slippage.
        // TODO: Ensure amount < maxLongAmount
        // TODO: Idle liquidity implementation
        uint256 amount = _idle();
        IERC20(_asset).approve(_hyperdrive, amount);
        (uint256 maturityTime, uint256 bondAmount) = IHyperdrive(_hyperdrive)
            .openLong(
                amount,
                _minOpenLongOutput(amount),
                _minVaultSharePrice(amount),
                IHyperdrive.Options(address(this), _asBase, "")
            );

        // Update positions to reflect the newly opened long.
        _positions.open(maturityTime, bondAmount, vaultSharePrice);
    }

    /// @dev Account for newly purchased bonds within the `PositionManager`.
    /// @param _maturityTime Maturity time for the newly purchased bonds.
    /// @param _bondAmountPurchased Amount of bonds purchased.
    // function _handleOpenLong(
    //     uint128 _maturityTime,
    //     uint128 _bondAmountPurchased
    // ) internal {
    //     // Revert if the incoming position's `maturityTime`
    //     // is sooner than the most recently added position's maturity.
    //     if (
    //         _positions.count() != 0 &&
    //         _decodePosition(_positions.back()).maturityTime > _maturityTime
    //     ) {
    //         revert IEverlong.InconsistentPositionMaturity();
    //     }
    //     // A position already exists with the incoming `maturityTime`.
    //     // The existing position's `bondAmount` is updated.
    //     else if (
    //         _positions.count() != 0 &&
    //         _decodePosition(_positions.back()).maturityTime == _maturityTime
    //     ) {
    //         Position memory _oldPosition = _decodePosition(
    //             _positions.popBack()
    //         );
    //         _positions.pushBack(
    //             _encodePosition(
    //                 _maturityTime,
    //                 _oldPosition.bondAmount + _bondAmountPurchased
    //             )
    //         );
    //         emit PositionUpdated(
    //             _maturityTime,
    //             _oldPosition.bondAmount + _bondAmountPurchased,
    //             _positions.length() - 1
    //         );
    //     }
    //     // No position exists with the incoming `maturityTime`.
    //     // Push a new position to the end of the queue.
    //     else {
    //         _positions.pushBack(
    //             _encodePosition(_maturityTime, _bondAmountPurchased)
    //         );
    //         emit PositionOpened(
    //             _maturityTime,
    //             _bondAmountPurchased,
    //             _positions.length() - 1
    //         );
    //     }
    // }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Closing (Internal)                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc EverlongBase
    function _increaseIdle(
        uint256 _target
    ) internal override returns (uint256 idle) {
        // Obtain the current amount of idle held by Everlong and return if
        // it is above the target.
        idle = IERC20(_asset).balanceOf(address(this));
        if (idle >= _target) return idle;

        // Close all matured positions and return if updated idle is above
        // the target.
        idle += _closeMaturedPositions();
        if (idle >= _target) return idle;

        // Close immature positions from oldest to newest until idle is
        // above the target.
        uint256 positionCount = _positions.count();
        Position memory position;
        while (positionCount > 0) {
            position = getPosition(0);

            uint256 estimatedProceeds = estimateLongProceeds(
                position.quantity,
                HyperdriveUtils.calculateTimeRemaining(
                    IHyperdrive(_hyperdrive),
                    _positions._avgMaturity
                ),
                position.vaultSharePrice,
                IHyperdrive(_hyperdrive).getPoolInfo().vaultSharePrice
            );

            // Close the position and add output to the current idle.
            uint256 proceeds = IHyperdrive(_hyperdrive).closeLong(
                position.maturity,
                position.quantity,
                _minCloseLongOutput(position.maturity, position.quantity),
                IHyperdrive.Options(address(this), _asBase, "")
            );

            if (estimatedProceeds < proceeds) {
                _target -= proceeds - estimatedProceeds;
            }
            idle += proceeds;

            // Update accounting for the closed position.
            _positions.close(position.quantity);

            // Return if the updated idle is above the target.
            if (idle >= _target) return idle;

            positionCount--;
        }

        // Revert since all positions are closed and the target idle is
        // has not been met;
        // revert IEverlong.TargetIdleTooHigh();
    }

    /// @dev Close all matured positions.
    /// @return output Output received from closing the positions.
    function _closeMaturedPositions() internal returns (uint256 output) {
        // Loop through mature positions and close them all.
        // TODO: Enable closing of mature positions incrementally to avoid
        //       the case where the # of mature positions exceeds the max
        //       gas per block.
        Position memory position;
        while (hasMaturedPositions()) {
            // Retrieve the oldest matured position and close it.
            position = _positions.at(0);
            output += IHyperdrive(_hyperdrive).closeLong(
                position.maturity,
                position.quantity,
                _minCloseLongOutput(position.maturity, position.quantity),
                IHyperdrive.Options(address(this), _asBase, "")
            );

            // Update positions to reflect the newly closed long.
            _positions.close(position.quantity);
            // _handleCloseLong(uint128(_position.bondAmount));
        }
    }

    // PERF: Popping then pushing the same position is inefficient.
    /// @dev Account for closed bonds at the oldest `maturityTime`
    ///      within the `PositionManager`.
    /// @param _bondAmountClosed Amount of bonds closed.
    // function _handleCloseLong(uint128 _bondAmountClosed) internal {
    //     // Remove the oldest position from the front queue.
    //     Position memory _position = _decodePosition(_positions.popFront());
    //
    //     // Compare the input bond amount to the most mature position's
    //     // `bondAmount`.
    //     if (_bondAmountClosed > _position.bondAmount) {
    //         revert IEverlong.InconsistentPositionBondAmount();
    //     }
    //     // The amount to close equals the position size.
    //     // Nothing further needs to be done.
    //     else if (_bondAmountClosed == _position.bondAmount) {
    //         emit PositionClosed(_position.maturityTime);
    //     } else {
    //         // The amount to close is not equal to the position size.
    //         // Push the position less the amount of longs closed to the front.
    //         _positions.pushFront(
    //             _encodePosition(
    //                 _position.maturityTime,
    //                 _position.bondAmount - _bondAmountClosed
    //             )
    //         );
    //         emit PositionUpdated(
    //             _position.maturityTime,
    //             _position.bondAmount - _bondAmountClosed,
    //             0
    //         );
    //     }
    // }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Encoding/Decoding                              │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Encodes the `_maturityTime` and `_bondAmount` into bytes32
    ///      to store in the queue.
    /// @param _maturityTime Timestamp the position matures.
    /// @param _bondAmount Amount of bonds in the position.
    /// @return The bytes32 encoded `Position`.
    // function _encodePosition(
    //     uint128 _maturityTime,
    //     uint128 _bondAmount
    // ) public pure returns (bytes32) {
    //     return bytes32((uint256(_maturityTime) << 128) | uint256(_bondAmount));
    // }

    /// @dev Decodes the bytes32 data into a `Position` struct.
    /// @param _position The bytes32 encoded data.
    /// @return The decoded `Position`.
    // function _decodePosition(
    //     bytes32 _position
    // ) public pure returns (Position memory) {
    //     uint128 _maturityTime = uint128(uint256(_position) >> 128);
    //     uint128 _bondAmount = uint128(uint256(_position));
    //     return Position(_maturityTime, _bondAmount);
    // }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongPositions
    function getPositionCount() public view returns (uint256) {
        return _positions.count();
    }

    /// @inheritdoc IEverlongPositions
    function getPosition(
        uint256 _index
    ) public view returns (Position memory position) {
        return _positions.at(_index);
    }

    /// @inheritdoc IEverlongPositions
    function hasMaturedPositions() public view returns (bool) {
        // Return false if there are no positions.
        if (_positions.count() == 0) return false;

        // Return true if the current block timestamp is after
        // the oldest position's `maturityTime`.
        return (_positions.at(0).maturity <= block.timestamp);
    }

    /// @inheritdoc IEverlongPositions
    function hasSufficientIdle() public view returns (bool) {
        // Return whether the current excess liquidity is greater than
        // Hyperdrive's minimum transaction amount.
        return
            _idle() >=
            IHyperdrive(_hyperdrive).getPoolConfig().minimumTransactionAmount;
    }

    // TODO: Consider storing hyperdrive's minimumTransactionAmount.
    /// @inheritdoc IEverlongPositions
    function canRebalance() public view returns (bool) {
        return hasMaturedPositions() || hasSufficientIdle();
    }

    // FIXME: Add comment
    function avgMaturity() public view returns (uint256) {
        return _positions._avgMaturity;
    }

    // FIXME: Add comment
    function quantity() public view returns (uint256) {
        return _positions._quantity;
    }

    // FIXME: Add comment
    function avgVaultSharePrice() public view returns (uint256) {
        return _positions._avgVaultSharePrice;
    }
}
