// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { IEverlong } from "../interfaces/IEverlong.sol";
import { Position } from "../types/Position.sol";

library PositionManager {
    using FixedPointMath for uint256;

    // FIXME: Add Comment
    struct PositionQueue {
        uint256 _begin;
        uint256 _end;
        uint256 _quantity;
        uint256 _avgMaturity;
        uint256 _avgVaultSharePrice;
        mapping(uint256 index => Position) _data;
    }

    // FIXME: Add Comment
    function open(
        PositionQueue storage p,
        uint256 _maturity,
        uint256 _quantity,
        uint256 _vaultSharePrice
    ) internal {
        if (count(p) == 0 || back(p).maturity != _maturity) {
            pushBack(p, Position(_maturity, _quantity, _vaultSharePrice));
            p._avgMaturity = FixedPointMath.updateWeightedAverage(
                p._avgMaturity,
                p._quantity,
                _maturity,
                _quantity,
                true
            );
            p._avgVaultSharePrice = FixedPointMath.updateWeightedAverage(
                p._avgVaultSharePrice,
                p._quantity,
                _vaultSharePrice,
                _quantity,
                true
            );
            p._quantity += _quantity;
        } else {
            increase(p, count(p) - 1, _quantity, _vaultSharePrice);
        }
    }

    // FIXME: Add Comment
    function close(PositionQueue storage p, uint256 _quantity) internal {
        Position memory position = at(p, 0);
        if (at(p, 0).quantity == _quantity) {
            popFront(p);
            p._avgMaturity = FixedPointMath.updateWeightedAverage(
                p._avgMaturity,
                p._quantity,
                position.maturity,
                position.quantity,
                false
            );
            p._avgVaultSharePrice = FixedPointMath.updateWeightedAverage(
                p._avgVaultSharePrice,
                p._quantity,
                position.vaultSharePrice,
                position.quantity,
                false
            );
            p._quantity -= position.quantity;
        } else {
            decrease(p, 0, _quantity);
        }
    }

    // FIXME: Add Comment
    function increase(
        PositionQueue storage p,
        uint256 _index,
        uint256 _quantity,
        uint256 _vaultSharePrice
    ) internal {
        // Update the position.
        Position storage position = at(p, _index);
        position.vaultSharePrice = FixedPointMath.updateWeightedAverage(
            position.vaultSharePrice,
            position.quantity,
            _vaultSharePrice,
            _quantity,
            true
        );
        position.quantity += _quantity;
        // Update averages.
        p._avgMaturity = FixedPointMath.updateWeightedAverage(
            p._avgMaturity,
            p._quantity,
            position.maturity,
            _quantity,
            true
        );
        p._avgVaultSharePrice = FixedPointMath.updateWeightedAverage(
            p._avgVaultSharePrice,
            p._quantity,
            position.vaultSharePrice,
            _quantity,
            true
        );
        p._quantity += _quantity;
    }

    // FIXME: Add Comment
    function decrease(
        PositionQueue storage p,
        uint256 _index,
        uint256 _quantity
    ) internal {
        Position storage position = at(p, _index);
        position.quantity -= _quantity;
        p._avgMaturity = FixedPointMath.updateWeightedAverage(
            p._avgMaturity,
            p._quantity,
            position.maturity,
            position.quantity,
            false
        );
        p._avgVaultSharePrice = FixedPointMath.updateWeightedAverage(
            p._avgVaultSharePrice,
            p._quantity,
            position.vaultSharePrice,
            position.quantity,
            false
        );
        p._quantity -= _quantity;
    }

    // FIXME: Add Comment
    function back(
        PositionQueue storage p
    ) internal view returns (Position storage) {
        if (empty(p)) revert IEverlong.PositionOutOfBounds();
        unchecked {
            return p._data[p._end - 1];
        }
    }

    // FIXME: Add Comment
    function popBack(
        PositionQueue storage p
    ) internal returns (Position storage value) {
        unchecked {
            uint256 backIndex = p._end;
            if (backIndex == p._begin) revert IEverlong.PositionQueueEmpty();
            --backIndex;
            value = p._data[backIndex];
            delete p._data[backIndex];
            p._end = backIndex;
        }
    }

    // FIXME: Add Comment
    function pushBack(PositionQueue storage p, Position memory value) internal {
        unchecked {
            uint256 backIndex = p._end;
            if (backIndex + 1 == p._begin) revert IEverlong.PositionQueueFull();
            p._data[backIndex] = value;
            p._end = backIndex + 1;
        }
    }

    // FIXME: Add Comment
    function front(
        PositionQueue storage p
    ) internal view returns (Position storage) {
        if (empty(p)) revert IEverlong.PositionOutOfBounds();
        return p._data[p._begin];
    }

    // FIXME: Add Comment
    function popFront(
        PositionQueue storage p
    ) internal returns (Position storage value) {
        unchecked {
            uint256 frontIndex = p._begin;
            if (frontIndex == p._end) revert IEverlong.PositionQueueEmpty();
            value = p._data[frontIndex];
            delete p._data[frontIndex];
            p._begin = frontIndex + 1;
        }
    }

    // FIXME: Add Comment
    function pushFront(
        PositionQueue storage p,
        Position memory value
    ) internal {
        unchecked {
            uint256 frontIndex = p._begin - 1;
            if (frontIndex == p._end) revert IEverlong.PositionQueueFull();
            p._data[frontIndex] = value;
            p._begin = frontIndex;
        }
    }

    // FIXME: Add Comment
    function at(
        PositionQueue storage p,
        uint256 _index
    ) internal view returns (Position storage) {
        if (_index >= count(p)) revert IEverlong.PositionOutOfBounds();
        unchecked {
            return p._data[p._begin + uint256(_index)];
        }
    }

    // FIXME: Add Comment
    function empty(PositionQueue storage p) internal view returns (bool) {
        return p._end == p._begin;
    }

    /// @dev Number of active positions.
    /// @return Active position count.
    function count(PositionQueue storage p) internal view returns (uint256) {
        unchecked {
            return uint256(p._end - p._begin);
        }
    }

    // FIXME: Add Comment
    function clear(PositionQueue storage p) internal {
        p._begin = 0;
        p._end = 0;
    }

    // FIXME: Add Comment
    function quantity(PositionQueue storage p) internal view returns (uint256) {
        return p._quantity;
    }

    // FIXME: Add Comment
    function avgMaturity(
        PositionQueue storage p
    ) internal view returns (uint256) {
        return p._avgMaturity;
    }

    // FIXME: Add Comment
    function avgVaultSharePrice(
        PositionQueue storage p
    ) internal view returns (uint256) {
        return p._avgVaultSharePrice;
    }
}
