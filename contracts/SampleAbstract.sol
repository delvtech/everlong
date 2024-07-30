// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// EverlongAdmin
// @author DELV
// @title EverlongAdmin
// @notice Permissioning for Everlong.
// @custom:disclaimer The language used in this code is for coding convenience
//                    only, and is not intended to, and does not, have any
//                    particular legal or regulatory significance.
abstract contract SampleAbstract {
    function getPositionCount() public virtual returns (uint256);

    function hello() public pure returns (string memory) {
        return "hi";
    }
}
