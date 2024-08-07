// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IEverlong } from "../interfaces/IEverlong.sol";
import { IEverlongAdmin } from "../interfaces/IEverlongAdmin.sol";
import { EverlongStorage } from "./EverlongStorage.sol";

/// @author DELV
/// @title EverlongAdmin
/// @notice Permissioning for Everlong.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongAdmin is EverlongStorage, IEverlongAdmin {
    // ╭─────────────────────────────────────────────────────────╮
    // │ Modifiers                                               │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Ensures that the contract is being called by admin.
    modifier onlyAdmin() {
        if (msg.sender != _admin) {
            revert IEverlong.Unauthorized();
        }
        _;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongAdmin
    function setAdmin(address admin_) external onlyAdmin {
        _admin = admin_;
        emit AdminUpdated(admin_);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongAdmin
    function admin() external view returns (address) {
        return _admin;
    }
}
