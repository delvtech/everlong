// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlong } from "../interfaces/IEverlong.sol";
import { IEverlongPositions } from "../interfaces/IEverlongPositions.sol";
import { Position } from "../types/Position.sol";
import { EverlongBase } from "./EverlongBase.sol";

/// @author DELV
/// @title EverlongPositions
/// @notice Everlong bond position management.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongPositions is EverlongBase, IEverlongPositions {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongPositions
    function rebalance() public {
        // Close all mature positions (if present) so that the proceeds can be
        // used to purchase longs.
        if (hasMaturedPositions()) {
            _closeMaturedPositions();
        }

        // Spend Everlong's excess idle liquidity (if sufficient) on opening a long.
        if (hasSufficientExcessLiquidity()) {
            _spendExcessLiquidity();
        }

        // Emit the `Rebalanced()` event.
        emit Rebalanced();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Virtual                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    // TODO: Implement idle liquidity and possibly remove.
    /// @dev Calculates the amount of excess liquidity that can be spent opening longs.
    /// @dev Can be overridden by child contracts.
    /// @return Amount of excess liquidity that can be spent opening longs.
    function _excessLiquidity() internal view virtual returns (uint256) {
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
    function _spendExcessLiquidity() internal {
        // Open the long position with the available excess liquidity.
        // TODO: Worry about slippage.
        // TODO: Ensure amount < maxLongAmount
        // TODO: Idle liquidity implementation
        uint256 _amount = _excessLiquidity();
        IERC20(_asset).approve(hyperdrive, _amount);
        (uint256 _maturityTime, uint256 _bondAmount) = IHyperdrive(hyperdrive)
            .openLong(
                _amount,
                _minOpenLongOutput(_amount),
                _minVaultSharePrice(_amount),
                IHyperdrive.Options(address(this), _asBase, "")
            );

        // Update positions to reflect the newly opened long.
        _handleOpenLong(uint128(_maturityTime), uint128(_bondAmount));
    }

    /// @dev Account for newly purchased bonds within the `PositionManager`.
    /// @param _maturityTime Maturity time for the newly purchased bonds.
    /// @param _bondAmountPurchased Amount of bonds purchased.
    function _handleOpenLong(
        uint128 _maturityTime,
        uint128 _bondAmountPurchased
    ) internal {
        // Compare the maturity time of the purchased bonds
        // to the most recent position's `maturityTime`.
        if (
            _positions.length() != 0 &&
            _decodePosition(_positions.back()).maturityTime > _maturityTime
        ) {
            // Revert because the incoming position's `maturityTime`
            // is sooner than the most recently added position's maturity.
            revert IEverlong.InconsistentPositionMaturity();
        } else if (
            _positions.length() != 0 &&
            _decodePosition(_positions.back()).maturityTime == _maturityTime
        ) {
            // A position already exists with the incoming `maturityTime`.
            // The existing position's `bondAmount` is updated.
            Position memory _oldPosition = _decodePosition(
                _positions.popBack()
            );
            _positions.pushBack(
                _encodePosition(
                    _maturityTime,
                    _oldPosition.bondAmount + _bondAmountPurchased
                )
            );
            emit PositionUpdated(
                _maturityTime,
                _oldPosition.bondAmount + _bondAmountPurchased,
                _positions.length() - 1
            );
        } else {
            // No position exists with the incoming `maturityTime`.
            // Push a new position to the end of the queue.
            _positions.pushBack(
                _encodePosition(_maturityTime, _bondAmountPurchased)
            );
            emit PositionOpened(
                _maturityTime,
                _bondAmountPurchased,
                _positions.length() - 1
            );
        }
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Closing (Internal)                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Close all matured positions.
    function _closeMaturedPositions() internal {
        // Loop through mature positions and close them all.
        Position memory _position;
        // TODO: Enable closing of mature positions incrementally to avoid
        //       the case where the # of mature positions exceeds the max
        //       gas per block.
        while (hasMaturedPositions()) {
            // Retrieve the oldest matured position and close it.
            _position = getPosition(0);
            IHyperdrive(hyperdrive).closeLong(
                _position.maturityTime,
                _position.bondAmount,
                _minCloseLongOutput(
                    _position.maturityTime,
                    _position.bondAmount
                ),
                IHyperdrive.Options(address(this), _asBase, "")
            );

            // Update positions to reflect the newly closed long.
            _handleCloseLong(uint128(_position.bondAmount));
        }
    }

    // PERF: Popping then pushing the same position is inefficient.
    /// @dev Account for closed bonds at the oldest `maturityTime`
    ///      within the `PositionManager`.
    /// @param _bondAmountClosed Amount of bonds closed.
    function _handleCloseLong(uint128 _bondAmountClosed) internal {
        // Remove the oldest position from the front queue.
        Position memory _position = _decodePosition(_positions.popFront());

        // Compare the input bond amount to the most mature position's
        // `bondAmount`.
        if (_bondAmountClosed > _position.bondAmount) {
            revert IEverlong.InconsistentPositionBondAmount();
        }
        // The amount to close equals the position size.
        // Nothing further needs to be done.
        else if (_bondAmountClosed == _position.bondAmount) {
            emit PositionClosed(_position.maturityTime);
        } else {
            // The amount to close is not equal to the position size.
            // Push the position less the amount of longs closed to the front.
            _positions.pushFront(
                _encodePosition(
                    _position.maturityTime,
                    _position.bondAmount - _bondAmountClosed
                )
            );
            emit PositionUpdated(
                _position.maturityTime,
                _position.bondAmount - _bondAmountClosed,
                0
            );
        }
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Encoding/Decoding                              │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Encodes the `_maturityTime` and `_bondAmount` into bytes32
    ///      to store in the queue.
    /// @param _maturityTime Timestamp the position matures.
    /// @param _bondAmount Amount of bonds in the position.
    /// @return The bytes32 encoded `Position`.
    function _encodePosition(
        uint128 _maturityTime,
        uint128 _bondAmount
    ) public pure returns (bytes32) {
        return bytes32((uint256(_maturityTime) << 128) | uint256(_bondAmount));
    }

    /// @dev Decodes the bytes32 data into a `Position` struct.
    /// @param _position The bytes32 encoded data.
    /// @return The decoded `Position`.
    function _decodePosition(
        bytes32 _position
    ) public pure returns (Position memory) {
        uint128 _maturityTime = uint128(uint256(_position) >> 128);
        uint128 _bondAmount = uint128(uint256(_position));
        return Position(_maturityTime, _bondAmount);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongPositions
    function getPositionCount() public view returns (uint256) {
        return _positions.length();
    }

    /// @inheritdoc IEverlongPositions
    function getPosition(
        uint256 _index
    ) public view returns (Position memory position) {
        position = _decodePosition(_positions.at(_index));
    }

    /// @inheritdoc IEverlongPositions
    function hasMaturedPositions() public view returns (bool) {
        // Return false if there are no positions.
        if (_positions.length() == 0) return false;

        // Return true if the current block timestamp is after
        // the oldest position's `maturityTime`.
        return (_decodePosition(_positions.at(0)).maturityTime <=
            block.timestamp);
    }

    /// @inheritdoc IEverlongPositions
    function hasSufficientExcessLiquidity() public view returns (bool) {
        // Return whether the current excess liquidity is greater than
        // Hyperdrive's minimum transaction amount.
        return
            _excessLiquidity() >=
            IHyperdrive(hyperdrive).getPoolConfig().minimumTransactionAmount;
    }

    // TODO: Consider storing hyperdrive's minimumTransactionAmount.
    /// @inheritdoc IEverlongPositions
    function canRebalance() public view returns (bool) {
        return hasMaturedPositions() || hasSufficientExcessLiquidity();
    }
}
