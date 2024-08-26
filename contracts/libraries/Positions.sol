// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/interfaces/IHyperdrive.sol";

library Positions {
    struct Position {
        uint128 quantity;
        uint128 maturity;
        uint128 cost;
        uint128 vaultSharePrice;
    }

    struct Positions {
        uint128 _begin;
        uint128 _end;
        mapping(uint128 index => Position) _data;
    }

    function open(
        Positions storage p,
        uint256 _quantity,
        uint256 _maturity,
        uint256 _cost,
        uint256 _vaultSharePrice
    ) internal {
        if (count(p) == 0 || back(p).maturity != _maturity) {
            pushBack(
                p,
                Position(_quantity, _maturity, _cost, _vaultSharePrice)
            );
        } else {}
    }

    // at
    function at(
        Positions storage p,
        uint256 _index
    ) internal view returns (Position storage) {
        if (_index >= count(p)) revert("Out of bounds");
        unchecked {
            return p._data[p._begin + uint128(_index)];
        }
    }

    function increase(
        Positions storage p,
        uint256 _index,
        uint256 _quantity,
        uint256 _cost,
        uint256 _vaultSharePrice
    ) internal {
        Position storage position = at(p, _index);
        position.vaultSharePrice =
            (position.quantity *
                position.vaultSharePrice +
                _quantity *
                _vaultSharePrice) /
            (position.quantity + _quantity);
        position.quantity += _quantity;
        position.cost += _cost;
    }

    function increase(
        Positions storage p,
        uint256 _index,
        uint256 _quantity,
        uint256 _cost,
        uint256 _vaultSharePrice
    ) internal {
        Position storage position = at(p, _index);
        position.vaultSharePrice =
            (position.quantity *
                position.vaultSharePrice +
                _quantity *
                _vaultSharePrice) /
            (position.quantity + _quantity);
        position.quantity += _quantity;
        position.cost += _cost;
    }

    // back
    function back(
        Positions storage p
    ) internal view returns (Position storage) {
        if (empty(p)) revert("Empty");
        unchecked {
            return p._data[p._end - 1];
        }
    }

    // popBack
    function popBack(Positions storage p) internal returns (Position storage) {
        unchecked {
            uint128 backIndex = p._end;
            if (backIndex == p._begin) revert("Empty");
            --backIndex;
            value = p._data[backIndex];
            delete p._data[backIndex];
            p._end = backIndex;
        }
    }

    // pushBack
    function pushBack(Positions storage p, Position memory value) internal {
        unchecked {
            uint128 backIndex = p._end;
            if (backIndex + 1 == p._begin) revert("Resource Error");
            deque._data[backIndex] = value;
            deque._end = backIndex + 1;
        }
    }

    // front
    function front(
        Positions storage p
    ) internal view returns (Position storage) {
        if (empty(p)) revert("Out of bounds");
        return p._data[p._begin];
    }

    // popFront
    function popFront(Positions storage p) internal returns (Position storage) {
        unchecked {
            uint128 frontIndex = p._begin;
            if (frontIndex == p._end) revert("Empty");
            value = p._data[frontIndex];
            delete p._data[frontIndex];
            p._begin = frontIndex + 1;
        }
    }

    // pushFront
    function pushFront(Positions storage p, Position memory value) internal {
        unchecked {
            uint128 frontIndex = p._begin - 1;
            if (frontIndex == p._end) revert("Resource Error");
            p._data[frontIndex] = value;
            p._begin = frontIndex;
        }
    }

    function empty(Positions storage p) internal view returns (bool) {
        return p._end == p._begin;
    }

    /// @dev Number of active positions.
    /// @return Active position count.
    function count(Positions storage p) internal view returns (uint256) {
        unchecked {
            return uint256(p._end - p._begin);
        }
    }
}
