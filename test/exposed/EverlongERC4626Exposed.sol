// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { Everlong } from "../../contracts/Everlong.sol";

/// @title EverlongERC4626Exposed
/// @dev Exposes all internal functions for the `EverlongERC4626` contract.
abstract contract EverlongERC4626Exposed is Everlong {
    function exposed_beforeWithdraw(uint256 _assets, uint256 _shares) public {
        return _beforeWithdraw(_assets, _shares);
    }

    function exposed_afterDeposit(uint256 _assets, uint256 _shares) public {
        return _afterDeposit(_assets, _shares);
    }
}
