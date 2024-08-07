// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { EVERLONG_KIND, EVERLONG_VERSION } from "../libraries/Constants.sol";
import { EverlongAdmin } from "./EverlongAdmin.sol";
import { EverlongERC4626 } from "./EverlongERC4626.sol";

// TODO: Reassess whether centralized configuration management makes sense.
//       https://github.com/delvtech/everlong/pull/2#discussion_r1703799747
/// @author DELV
/// @title EverlongBase
/// @notice Base contract for Everlong.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongBase is EverlongAdmin, EverlongERC4626 {
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

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

        // Give 1 wei approval to make the slot "dirty".
        IERC20(_asset).approve(_hyperdrive, 1);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Returns the kind of the Everlong instance.
    /// @return Everlong contract kind.
    function kind() public view virtual returns (string memory) {
        return EVERLONG_KIND;
    }

    /// @notice Returns the version of the Everlong instance.
    /// @return Everlong contract version.
    function version() public view virtual returns (string memory) {
        return EVERLONG_VERSION;
    }
}
