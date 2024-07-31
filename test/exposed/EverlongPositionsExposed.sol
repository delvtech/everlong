// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { EverlongBase } from "../../contracts/internal/EverlongBase.sol";
import { EverlongPositions } from "../../contracts/internal/EverlongPositions.sol";
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";

/// @title EverlongPositionsExposed
/// @dev Exposes all internal functions for the `EverlongPositions` contract.
contract EverlongPositionsExposed is EverlongPositions, Test {
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
    ) EverlongBase(name_, symbol_, hyperdrive_, asBase_) {}

    /// @dev Spend the excess idle liquidity for the Everlong contract.
    /// @dev Can be overridden by implementing contracts to configure
    ///      how much idle to spend and how it is spent.
    function exposed_spendExcessIdle() public {
        return _spendExcessIdle();
    }

    /// @dev Open a long position from the Hyperdrive contract
    ///      for the input `_amount`.
    /// @dev Can be overridden by implementing contracts to configure slippage
    ///      and minimum output.
    /// @param _amount Amount of `_asset` to spend towards the long.
    /// @return _maturityTime Maturity time of the newly opened long.
    /// @return _bondAmount Amount of bonds received from the newly opened long.
    function exposed_openLong(
        uint256 _amount
    ) public returns (uint256 _maturityTime, uint256 _bondAmount) {
        _openLong(_amount);
    }

    /// @dev Account for newly purchased bonds within the `PositionManager`.
    /// @param _maturityTime Maturity time for the newly purchased bonds.
    /// @param _bondAmountPurchased Amount of bonds purchased.
    function exposed_handleOpenLong(
        uint128 _maturityTime,
        uint128 _bondAmountPurchased
    ) public {
        return _handleOpenLong(_maturityTime, _bondAmountPurchased);
    }

    /// @dev Close all matured positions.
    function exposed_closeMaturedPositions() public {
        return _closeMaturedPositions();
    }

    /// @dev Account for closed bonds at the oldest `maturityTime`
    ///      within the `PositionManager`.
    /// @param _bondAmountClosed Amount of bonds closed.
    function exposed_handleCloseLong(uint128 _bondAmountClosed) public {
        return _handleCloseLong(_bondAmountClosed);
    }
}
