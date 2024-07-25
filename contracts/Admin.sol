// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { IAdmin } from "./interfaces/IAdmin.sol";

// EverlongAdmin
// @author DELV
// @title EverlongAdmin
// @notice Permissioning for Everlong.
// @custom:disclaimer The language used in this code is for coding convenience
//                    only, and is not intended to, and does not, have any
//                    particular legal or regulatory significance.
contract Admin is IAdmin {
    /// @inheritdoc IAdmin
    address public admin;

    /// @dev Ensures that the contract is being called by admin.
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert IAdmin.Unauthorized();
        }
        _;
    }

    /// @dev Initialize the admin address to the contract deployer.
    constructor() {
        admin = msg.sender;
    }

    /// @inheritdoc IAdmin
    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
        emit AdminUpdated(_admin);
    }
}
