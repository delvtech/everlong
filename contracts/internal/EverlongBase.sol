// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { EverlongAdmin } from "./EverlongAdmin.sol";
import { EverlongERC4626 } from "./EverlongERC4626.sol";
import { IEverlongEvents } from "../interfaces/IEverlongEvents.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { ERC4626 } from "solady/tokens/ERC4626.sol";

/// @author DELV
/// @title EverlongBase
/// @notice Base contract for Everlong.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongBase is EverlongERC4626, IEverlongEvents {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Storage                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// Admin ///

    /// @dev Address of the contract admin.
    address internal _admin;

    /// Hyperdrive ///

    /// @dev Address of the Hyperdrive instance wrapped by Everlong.
    address public immutable hyperdrive;

    /// @dev Whether to use Hyperdrive's base token to purchase bonds.
    //          If false, use the Hyperdrive's `vaultSharesToken`.
    bool internal immutable _asBase;

    /// Positions ///

    // TODO: Reassess using a more tailored data structure.
    /// @dev Utility data structure to manage the position queue.
    ///      Supports pushing and popping from both the front and back.
    DoubleEndedQueue.Bytes32Deque internal _positions;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Constructor                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Initial configuration paramters for Everlong.
    /// @param _name Name of the ERC20 token managed by Everlong.
    /// @param _symbol Symbol of the ERC20 token managed by Everlong.
    /// @param _hyperdrive Address of the Hyperdrive instance wrapped by Everlong.
    /// @param __asBase Whether to use Hyperdrive's base token for bond purchases.
    constructor(
        string memory _name,
        string memory _symbol,
        address _hyperdrive,
        bool __asBase
    )
        EverlongERC4626(
            _name,
            _symbol,
            __asBase
                ? IHyperdrive(_hyperdrive).baseToken()
                : IHyperdrive(_hyperdrive).vaultSharesToken()
        )
    {
        // Store constructor parameters.
        hyperdrive = _hyperdrive;
        _asBase = __asBase;
        _admin = msg.sender;

        // Give max approval for `_asset` to the hyperdrive contract.
        IERC20(_asset).approve(_hyperdrive, type(uint256).max);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Views                                                   │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Returns the kind of the Everlong instance.
    /// @return Everlong contract kind.
    function kind() public view virtual returns (string memory) {
        return "Everlong";
    }

    /// @notice Returns the version of the Everlong instance.
    /// @return Everlong contract version.
    function version() public view virtual returns (string memory) {
        return "v0.0.1";
    }
}
