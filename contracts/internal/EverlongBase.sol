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
contract EverlongBase is EverlongERC4626, IEverlongEvents {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Storage                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// Admin ///

    /// @dev Address of the contract admin.
    address internal _admin;

    /// Hyperdrive ///

    /// @dev Address of the Hyperdrive instance wrapped by Everlong.
    address internal immutable _hyperdrive;

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
    /// @param hyperdrive_ Address of the Hyperdrive instance wrapped by Everlong.
    /// @param name_ Name of the ERC20 token managed by Everlong.
    /// @param symbol_ Symbol of the ERC20 token managed by Everlong.
    /// @param asBase_ Whether to use Hyperdrive's base token for bond purchases.
    constructor(
        string memory name_,
        string memory symbol_,
        address hyperdrive_,
        bool asBase_
    )
        EverlongERC4626(
            name_,
            symbol_,
            asBase_
                ? IHyperdrive(hyperdrive_).baseToken()
                : IHyperdrive(hyperdrive_).vaultSharesToken()
        )
    {
        // Store constructor parameters.
        _hyperdrive = hyperdrive_;
        _asBase = asBase_;
        _admin = msg.sender;

        // Give max approval for `_asset` to the hyperdrive contract.
        IERC20(_asset).approve(hyperdrive_, type(uint256).max);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Views                                                   │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Returns the address of the underlying Hyperdrive instance.
    /// @return Hyperdrive address.
    function hyperdrive() public view returns (address) {
        return _hyperdrive;
    }

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
