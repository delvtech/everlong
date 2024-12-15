// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";

/// @author DELV
/// @title IERC20Wrappable
/// @notice Interface for an ERC20 token that can be wrapped/unwrapped.
/// @dev Since Yearn explicitly does not support rebasing tokens as
///      vault/strategy assets, wrapping is mandatory.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
interface IERC20Wrappable is IERC20 {
    /// @notice Wrap the input amount of assets.
    /// @param _unwrappedAmount Amount of assets to wrap.
    /// @return _wrappedAmount Amount of wrapped assets that are returned.
    function wrap(
        uint256 _unwrappedAmount
    ) external returns (uint256 _wrappedAmount);

    /// @notice Unwrap the input amount of assets.
    /// @param _wrappedAmount Amount of assets to unwrap.
    /// @return _unwrappedAmount Amount of unwrapped assets that are returned.
    function unwrap(
        uint256 _wrappedAmount
    ) external returns (uint256 _unwrappedAmount);
}
