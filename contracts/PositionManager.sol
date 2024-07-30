// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IPositionManager } from "./interfaces/IPositionManager.sol";
import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";

contract PositionManager is IPositionManager {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // TODO: Reassess using a more tailored data structure.
    /// @dev Utility data structure to manage the position queue.
    ///      Supports pushing and popping from both the front and back.
    DoubleEndedQueue.Bytes32Deque private _positions;

    /// @dev Last checkpoint time the portfolio was rebalanced.
    uint256 private _lastRebalancedTimestamp;

    /// @inheritdoc IPositionManager
    function getPositionCount() public view returns (uint256) {
        return _positions.length();
    }

    /// @inheritdoc IPositionManager
    function getPosition(
        uint256 _index
    ) public view returns (Position memory position) {
        position = _decodePosition(_positions.at(_index));
    }

    /// @inheritdoc IPositionManager
    function hasMaturedPositions() public view returns (bool) {
        // Return false if there are no positions.
        if (_positions.length() == 0) return false;
        Position memory _position = _decodePosition(_positions.at(0));

        // Return true if the current block timestamp is after
        // the oldest position's `maturityTime`.
        if (_position.maturityTime <= block.timestamp) {
            return true;
        }

        // Return false since the oldest position has not matured.
        return false;
    }

    /// @dev Account for newly purchased bonds within the `PositionManager`.
    /// @param _maturityTime Maturity time for the newly purchased bonds.
    /// @param _bondAmountPurchased Amount of bonds purchased.
    function _recordLongsOpened(
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

    /// @dev Account for closed bonds at the oldest `maturityTime`
    ///      within the `PositionManager`.
    /// @param _bondAmountClosed Amount of bonds closed.
    function _recordLongsClosed(uint128 _bondAmountClosed) internal {
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

    /// @dev Encodes the `_maturityTime` and `_bondAmount` into bytes32
    ///      to store in the queue.
    /// @param _maturityTime Timestamp the position matures.
    /// @param _bondAmount Amount of bonds in the position.
    /// @return The bytes32 encoded `Position`.
    function _encodePosition(
        uint128 _maturityTime,
        uint128 _bondAmount
    ) internal pure returns (bytes32) {
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
    ) internal pure returns (bytes32) {
        return
            (bytes32(bytes16(_position.maturityTime)) >> 128) |
            bytes32(bytes16(_position.bondAmount));
    }

    /// @dev Decodes the bytes32 data into a `Position` struct.
    /// @param _position The bytes32 encoded data.
    /// @return The decoded `Position`.
    function _decodePosition(
        bytes32 _position
    ) internal pure returns (Position memory) {
        uint128 _maturityTime = uint128(bytes16(_position << 128));
        uint128 _bondAmount = uint128(bytes16(_position));
        return Position(_maturityTime, _bondAmount);
    }
}
