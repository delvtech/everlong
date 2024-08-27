// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
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
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

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
}
