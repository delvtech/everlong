// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
import { IEverlongEvents } from "../interfaces/IEverlongEvents.sol";

// TODO: Reassess whether centralized configuration management makes sense.
//       https://github.com/delvtech/everlong/pull/2#discussion_r1703799747
/// @author DELV
/// @title EverlongStorage
/// @notice Base contract for Everlong.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongStorage is IEverlongEvents {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Storage                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    // ── Admin ──────────────────────────────────────────────────

    /// @dev Address of the contract admin.
    address internal _admin;

    // ── Hyperdrive ─────────────────────────────────────────────

    /// @dev Address of the Hyperdrive instance wrapped by Everlong.
    address public hyperdrive;

    /// @dev Whether to use Hyperdrive's base token to purchase bonds.
    //          If false, use the Hyperdrive's `vaultSharesToken`.
    bool internal _asBase;

    // ── Positions ──────────────────────────────────────────────

    // TODO: Reassess using a more tailored data structure.
    /// @dev Utility data structure to manage the position queue.
    ///      Supports pushing and popping from both the front and back.
    DoubleEndedQueue.Bytes32Deque internal _positions;

    // ── ERC4626 ────────────────────────────────────────────────

    /// @notice Virtual shares are used to mitigate inflation attacks.
    bool public constant useVirtualShares = true;

    /// @notice Used to reduce the feasibility of an inflation attack.
    /// TODO: Determine the appropriate value for our case. Current value
    ///       was picked arbitrarily.
    uint8 public constant decimalsOffset = 3;

    /// @dev Address of the token to use for Hyperdrive bond purchase/close.
    address internal _asset;

    // TODO: Remove in favor of more sophisticated position valuation.
    // TODO: Use some SafeMath library.
    /// @dev Virtual asset count to track amount deposited into Hyperdrive.
    uint256 internal _virtualAssets;

    /// @dev Decimals used by the `_asset`.
    uint8 internal _decimals;

    /// @dev Name of the Everlong token.
    string internal _name;

    /// @dev Symbol of the Everlong token.
    string internal _symbol;
}
