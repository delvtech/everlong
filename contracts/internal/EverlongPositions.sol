// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IEverlongPositions } from "../interfaces/IEverlongPositions.sol";
import { EverlongBase } from "./EverlongBase.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";

/// @author DELV
/// @title EverlongPositions
/// @notice Everlong bond position management.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongPositions is EverlongBase, IEverlongPositions {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Views                                                   │
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

    // TODO: Consider storing hyperdrive's minimumTransactionAmount.
    /// @inheritdoc IEverlongPositions
    function canRebalance() public view returns (bool) {
        return
            hasMaturedPositions() ||
            IERC20(_asset).balanceOf(address(this)) >=
            IHyperdrive(_hyperdrive).getPoolConfig().minimumTransactionAmount;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Public                                                  │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongPositions
    function rebalance() public override {
        // If there is no need for rebalancing, return.
        if (!canRebalance()) return;

        // First close all mature positions so that the proceeds can be
        // used to purchase longs.
        _closeMaturedPositions();

        // Spend Everlong's excess idle liquidity on opening a long.
        _spendExcessIdle();

        // Emit the `Rebalanced()` event.
        emit Rebalanced();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Opening (Internal)                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Spend the excess idle liquidity for the Everlong contract.
    /// @dev Can be overridden by implementing contracts to configure
    ///      how much idle to spend and how it is spent.
    function _spendExcessIdle() internal virtual {
        // Obtain the current balance of the contract.
        uint256 _currentBalance = IERC20(_asset).balanceOf(address(this));

        // Obtain the minimum transaction amount from the hyperdrive instance.
        uint256 _minTxAmount = IHyperdrive(_hyperdrive)
            .getPoolConfig()
            .minimumTransactionAmount;

        // Use the entire balance of the Everlong contract to open a long
        // if the balance is greater than hyperdrive's minimum tx amount.
        if (_currentBalance >= _minTxAmount) {
            (uint256 _maturityTime, uint256 _bondAmount) = _openLong(
                _currentBalance
            );
            // Update positions to reflect the newly opened long.
            _handleOpenLong(uint128(_maturityTime), uint128(_bondAmount));
        }
    }

    /// @dev Open a long position from the Hyperdrive contract
    ///      for the input `_amount`.
    /// @dev Can be overridden by implementing contracts to configure slippage
    ///      and minimum output.
    /// @param _amount Amount of `_asset` to spend towards the long.
    /// @return _maturityTime Maturity time of the newly opened long.
    /// @return _bondAmount Amount of bonds received from the newly opened long.
    function _openLong(
        uint256 _amount
    ) internal virtual returns (uint256 _maturityTime, uint256 _bondAmount) {
        // Obtain the current balance of the contract.
        // If the balance is greater than hyperdrive's min tx amount,
        // use it all to open longs.
        uint256 _currentBalance = IERC20(_asset).balanceOf(address(this));
        uint256 _minTxAmount = IHyperdrive(_hyperdrive)
            .getPoolConfig()
            .minimumTransactionAmount;
        if (_currentBalance >= _minTxAmount) {
            // TODO: Worry about slippage.
            (_maturityTime, _bondAmount) = IHyperdrive(_hyperdrive).openLong(
                _currentBalance,
                0,
                0,
                IHyperdrive.Options(address(this), _asBase, "")
            );
        }
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
            //  is sooner than the most recently added position's maturity.
            revert InconsistentPositionMaturity();
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
            _closeLong(
                uint256(_position.maturityTime),
                uint256(_position.bondAmount)
            );

            // Update positions to reflect the newly closed long.
            _handleCloseLong(uint128(_position.bondAmount));
        }
    }

    /// @dev Closes a long position from the Hyperdrive contract
    ///      for the input `_amount`.
    /// @dev Can be overridden by implementing contracts to configure slippage
    ///      and minimum output.
    /// @param _maturityTime Maturity time of the long to close.
    /// @param _bondAmount Amount of bonds to close from the position.
    /// @return _proceeds Amount of `asset` received from closing the long.
    function _closeLong(
        uint256 _maturityTime,
        uint256 _bondAmount
    ) internal virtual returns (uint256 _proceeds) {
        // Obtain the current balance of the contract.
        // If the balance is greater than hyperdrive's min tx amount,
        // use it all to open longs.
        // TODO: Worry about slippage.
        _proceeds = IHyperdrive(_hyperdrive).closeLong(
            _maturityTime,
            _bondAmount,
            0,
            IHyperdrive.Options(address(this), _asBase, "")
        );
    }

    /// @dev Account for closed bonds at the oldest `maturityTime`
    ///      within the `PositionManager`.
    /// @param _bondAmountClosed Amount of bonds closed.
    function _handleCloseLong(uint128 _bondAmountClosed) internal {
        // Remove the oldest position from the front queue.
        Position memory _position = _decodePosition(_positions.popFront());

        // Compare the input bond amount
        // to the most mature position's `bondAmount`.
        if (_bondAmountClosed > _position.bondAmount) {
            revert InconsistentPositionBondAmount();
        } else if (_bondAmountClosed == _position.bondAmount) {
            // The amount to close equals the position size.
            // Nothing further needs to be done.
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
        return
            (bytes32(bytes16(_maturityTime)) >> 128) |
            bytes32(bytes16(_bondAmount));
    }

    /// @dev Encodes the `Position` struct into bytes32
    ///      to store in the queue.
    /// @param _position The `Position` to encode.
    /// @return The bytes32 encoded `Position`.
    function _encodePosition(
        Position memory _position
    ) public pure returns (bytes32) {
        return
            (bytes32(bytes16(_position.maturityTime)) >> 128) |
            bytes32(bytes16(_position.bondAmount));
    }

    /// @dev Decodes the bytes32 data into a `Position` struct.
    /// @param _position The bytes32 encoded data.
    /// @return The decoded `Position`.
    function _decodePosition(
        bytes32 _position
    ) public pure returns (Position memory) {
        uint128 _maturityTime = uint128(bytes16(_position << 128));
        uint128 _bondAmount = uint128(bytes16(_position));
        return Position(_maturityTime, _bondAmount);
    }
}
