// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { IEverlong } from "../interfaces/IEverlong.sol";

/// @author DELV
/// @title PositionLibrary
/// @notice Library for interacting with {IEverlong.Position}s.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
library PositionLibrary {
    using FixedPointMath for uint256;
    using SafeCast for *;

    /// @notice Increase the position's bond count.
    /// @param _bondAmount Amount to increase the position's bond count by.
    function increase(
        IEverlong.Position storage self,
        uint256 _bondAmount
    ) internal {
        self.bondAmount += _bondAmount.toUint128();
    }

    /// @notice Decrease the position's bond count.
    /// @param _bondAmount Amount to increase the position's bond count by.
    function decrease(
        IEverlong.Position storage self,
        uint256 _bondAmount
    ) internal {
        self.bondAmount -= _bondAmount.toUint128();
    }

    /// @notice Reset the contents of a position.
    function clear(IEverlong.Position storage self) internal {
        self.maturityTime = 0;
        self.bondAmount = 0;
    }
}
