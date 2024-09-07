// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { IEverlong } from "../interfaces/IEverlong.sol";
import { PositionLibrary } from "./Position.sol";

library Portfolio {
    using FixedPointMath for uint256;
    using SafeCast for *;
    using PositionLibrary for IEverlong.Position;

    error IndexOutOfBounds();
    error QueueEmpty();
    error QueueFull();

    /// @dev The state of the portfolio which contains a double-ended queue
    ///      of {IEverlong.Position} along with the portfolio's average
    ///      maturity, vault share price, and total bond count.
    struct State {
        /// @dev Starting index for the double-ended queue structure.
        uint128 _begin;
        /// @dev Ending index for the double-ended queue structure.
        uint128 _end;
        /// @dev Weighted average maturity time for the portfolio.
        uint128 avgMaturityTime;
        /// @dev Total bond count of the portfolio.
        uint128 totalBonds;
        /// @dev Mapping of indices to {IEverlong.Position} for the
        ///      double-ended queue structure.
        mapping(uint256 index => IEverlong.Position) _q;
    }

    /// @notice Update portfolio accounting a newly-opened position.
    /// @param _maturityTime Maturity of the opened position.
    /// @param _bondAmount Amount of bonds in the opened position.
    function handleOpenPosition(
        State storage self,
        uint256 _maturityTime,
        uint256 _bondAmount
    ) internal {
        // Check whether the incoming maturity is already in the portfolio.
        // Since the portfolio's positions are stored as a queue (old -> new),
        // we need only check the 'tail' position.
        if (!isEmpty(self) && tail(self).maturityTime == _maturityTime) {
            // The maturity is already present in the portfolio, so update it
            // with the additional bonds and the price of those bonds.
            tail(self).increase(_bondAmount);
        } else {
            // The maturity is not in the portfolio, so add a new position.
            _addPosition(
                self,
                IEverlong.Position(uint128(_maturityTime), uint128(_bondAmount))
            );
        }

        // Update the portfolio's weighted averages.
        self.avgMaturityTime = _updateWeightedAverageDown(
            uint256(self.avgMaturityTime),
            self.totalBonds,
            _maturityTime,
            _bondAmount,
            true
        ).toUint128();

        // Update the portfolio's total bond count.
        self.totalBonds += uint128(_bondAmount);
    }

    /// @notice Update portfolio accounting for a newly-closed position.
    ///         Since the portfolio handles positions via a queue, the
    ///         position being closed always the oldest at the head.
    function handleClosePosition(State storage self) internal {
        if (isEmpty(self)) {
            // FIXME: custom error
            revert("ahhhh");
        }
        IEverlong.Position memory position = _removePosition(self);
        self.avgMaturityTime = _updateWeightedAverageDown(
            uint256(self.avgMaturityTime),
            self.totalBonds,
            position.maturityTime,
            position.bondAmount,
            false
        ).toUint128();
        self.totalBonds -= position.bondAmount;
    }

    /// @notice Obtain the position at the head of the queue.
    ///         This is the oldest position in the portfolio.
    function head(
        State storage self
    ) internal view returns (IEverlong.Position memory) {
        if (isEmpty(self)) revert IndexOutOfBounds();
        return self._q[self._begin];
    }

    /// @notice Obtain the position at the tail of the queue.
    ///         This is the most recent position in the portfolio.
    function tail(
        State storage self
    ) internal view returns (IEverlong.Position storage) {
        if (isEmpty(self)) revert IndexOutOfBounds();
        unchecked {
            return self._q[self._end - 1];
        }
    }

    /// @notice Retrieve the position at the specified location in the queue..
    /// @param _index Index in the queue to retrieve the position.
    /// @return The position at the specified location.
    function at(
        State storage self,
        uint256 _index
    ) internal view returns (IEverlong.Position memory) {
        if (_index >= positionCount(self)) revert IndexOutOfBounds();
        unchecked {
            return self._q[self._begin + uint256(_index)];
        }
    }

    /// @notice Returns whether the position queue is empty.
    /// @return True if the position queue is empty, false otherwise.
    function isEmpty(State storage self) internal view returns (bool) {
        return self._end == self._begin;
    }

    /// @notice Returns how many positions are currently in the queue.
    /// @return The queue's position count.
    function positionCount(State storage self) internal view returns (uint256) {
        unchecked {
            return uint256(self._end - self._begin);
        }
    }

    /// @dev Push a new {IEverlong.Position} to the position queue.
    /// @param value Position to be pushed.
    function _addPosition(
        State storage self,
        IEverlong.Position memory value
    ) internal {
        unchecked {
            uint128 backIndex = self._end;
            if (backIndex + 1 == self._begin) revert QueueFull();
            self._q[backIndex] = value;
            self._end = backIndex + 1;
        }
    }

    /// @dev Pop the oldest {IEverlong.Position} from the position queue.
    /// @return value A copy of the position that was just popped.
    function _removePosition(
        State storage self
    ) internal returns (IEverlong.Position memory value) {
        unchecked {
            uint128 frontIndex = self._begin;
            if (frontIndex == self._end) revert QueueEmpty();
            value = self._q[frontIndex];
            delete self._q[frontIndex];
            self._begin = frontIndex + 1;
        }
    }

    /// @dev Reset the queue, removing all positions.
    function _clear(State storage self) internal {
        self._begin = 0;
        self._end = 0;
    }

    /// @dev Updates a weighted average by adding or removing a weighted delta.
    /// @param _totalWeight The total weight before the update.
    /// @param _deltaWeight The weight of the new value.
    /// @param _average The weighted average before the update.
    /// @param _delta The new value.
    /// @return average The new weighted average.
    function _updateWeightedAverageDown(
        uint256 _average,
        uint256 _totalWeight,
        uint256 _delta,
        uint256 _deltaWeight,
        bool _isAdding
    ) internal pure returns (uint256 average) {
        // If the delta weight is zero, the average does not change.
        if (_deltaWeight == 0) {
            return _average;
        }

        // If the delta weight should be added to the total weight, we compute
        // the weighted average as:
        //
        // average = (totalWeight * average + deltaWeight * delta) /
        //           (totalWeight + deltaWeight)
        if (_isAdding) {
            // NOTE: Round down to underestimate the average.
            average = (_totalWeight.mulDown(_average) +
                _deltaWeight.mulDown(_delta)).divDown(
                    _totalWeight + _deltaWeight
                );

            // An important property that should always hold when we are adding
            // to the average is:
            //
            // min(_delta, _average) <= average <= max(_delta, _average)
            //
            // To ensure that this is always the case, we clamp the weighted
            // average to this range. We don't have to worry about the
            // case where average > _delta.max(average) because rounding down when
            // computing this average makes this case infeasible.
            uint256 minAverage = _delta.min(_average);
            if (average < minAverage) {
                average = minAverage;
            }
        }
        // If the delta weight should be subtracted from the total weight, we
        // compute the weighted average as:
        //
        // average = (totalWeight * average - deltaWeight * delta) /
        //           (totalWeight - deltaWeight)
        else {
            if (_totalWeight == _deltaWeight) {
                return 0;
            }

            // NOTE: Round down to underestimate the average.
            average = (_totalWeight.mulDown(_average) -
                _deltaWeight.mulUp(_delta)).divDown(
                    _totalWeight - _deltaWeight
                );
        }
    }
    /// @dev Updates a weighted average by adding or removing a weighted delta.
    /// @param _totalWeight The total weight before the update.
    /// @param _deltaWeight The weight of the new value.
    /// @param _average The weighted average before the update.
    /// @param _delta The new value.
    /// @return average The new weighted average.
    function _updateWeightedAverageUp(
        uint256 _average,
        uint256 _totalWeight,
        uint256 _delta,
        uint256 _deltaWeight,
        bool _isAdding
    ) internal pure returns (uint256 average) {
        // If the delta weight is zero, the average does not change.
        if (_deltaWeight == 0) {
            return _average;
        }

        // If the delta weight should be added to the total weight, we compute
        // the weighted average as:
        //
        // average = (totalWeight * average + deltaWeight * delta) /
        //           (totalWeight + deltaWeight)
        if (_isAdding) {
            // NOTE: Round up to underestimate the average.
            average = (_totalWeight.mulUp(_average) +
                _deltaWeight.mulUp(_delta)).divUp(_totalWeight + _deltaWeight);

            // An important property that should always hold when we are adding
            // to the average is:
            //
            // min(_delta, _average) <= average <= max(_delta, _average)
            //
            // To ensure that this is always the case, we clamp the weighted
            // average to this range. We don't have to worry about the
            // case where average > _delta.max(average) because rounding down when
            // computing this average makes this case infeasible.
            uint256 minAverage = _delta.min(_average);
            if (average < minAverage) {
                average = minAverage;
            }
        }
        // If the delta weight should be subtracted from the total weight, we
        // compute the weighted average as:
        //
        // average = (totalWeight * average - deltaWeight * delta) /
        //           (totalWeight - deltaWeight)
        else {
            if (_totalWeight == _deltaWeight) {
                return 0;
            }

            // NOTE: Round up to overestimate the average.
            average = (_totalWeight.mulUp(_average) -
                _deltaWeight.mulDown(_delta)).divUp(
                    _totalWeight - _deltaWeight
                );
        }
    }
}
