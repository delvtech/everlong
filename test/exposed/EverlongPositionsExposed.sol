// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { EverlongPositions } from "../../contracts/internal/EverlongPositions.sol";

/// @title EverlongPositionsExposed
/// @dev Exposes all internal functions for the `EverlongPositions` contract.
abstract contract EverlongPositionsExposed is EverlongPositions {
    /// @notice Initial configuration paramters for Everlong.
    /// @param hyperdrive_ Address of the Hyperdrive instance wrapped by Everlong.
    /// @param name_ Name of the ERC20 token managed by Everlong.
    /// @param symbol_ Symbol of the ERC20 token managed by Everlong.
    /// @param asBase_ Whether to use Hyperdrive's base token for bond purchases.
    // constructor(
    //     string memory name_,
    //     string memory symbol_,
    //     address hyperdrive_,
    //     bool asBase_
    // ) EverlongBase(name_, symbol_, hyperdrive_, asBase_) {}

    /// @notice Calculates the amount of excess liquidity that can be spent opening longs.
    /// @notice Can be overridden by child contracts.
    /// @return Amount of excess liquidity that can be spent opening longs.
    function exposed_excessLiquidity() public view virtual returns (uint256) {
        return _excessLiquidity();
    }

    /// @notice Calculates the minimum `openLong` output from Hyperdrive
    ///       given the amount of capital being spend.
    /// @notice Can be overridden by child contracts.
    /// @param _amount Amount of capital provided for `openLong`.
    /// @return Minimum number of bonds to receive from `openLong`.
    function exposed_minOpenLongOutput(
        uint256 _amount
    ) public view virtual returns (uint256) {
        return _minOpenLongOutput(_amount);
    }

    /// @notice Calculates the minimum vault share price at which to
    ///      open the long.
    /// @notice Can be overridden by child contracts.
    /// @param _amount Amount of capital provided for `openLong`.
    /// @return minimum vault share price for `openLong`.
    function exposed_minVaultSharePrice(
        uint256 _amount
    ) public view virtual returns (uint256) {
        return _minVaultSharePrice(_amount);
    }

    /// @notice Calculates the minimum proceeds Everlong will accept for
    ///      closing the long.
    /// @notice Can be overridden by child contracts.
    /// @param _maturityTime Maturity time of the long to close.
    /// @param _bondAmount Amount of bonds to close.
    function exposed_minCloseLongOutput(
        uint256 _maturityTime,
        uint256 _bondAmount
    ) public view returns (uint256) {
        return _minCloseLongOutput(_maturityTime, _bondAmount);
    }

    /// @notice Spend the excess idle liquidity for the Everlong contract.
    /// @notice Can be overridden by implementing contracts to configure
    ///      how much idle to spend and how it is spent.
    function exposed_spendExcessLiquidity() public {
        return _spendExcessLiquidity();
    }

    /// @notice Account for newly purchased bonds within the `PositionManager`.
    /// @param _maturityTime Maturity time for the newly purchased bonds.
    /// @param _bondAmountPurchased Amount of bonds purchased.
    function exposed_handleOpenLong(
        uint128 _maturityTime,
        uint128 _bondAmountPurchased
    ) public {
        return _handleOpenLong(_maturityTime, _bondAmountPurchased);
    }

    /// @notice Close all matured positions.
    function exposed_closeMaturedPositions() public {
        return _closeMaturedPositions();
    }

    /// @notice Account for closed bonds at the oldest `maturityTime`
    ///      within the `PositionManager`.
    /// @param _bondAmountClosed Amount of bonds closed.
    function exposed_handleCloseLong(uint128 _bondAmountClosed) public {
        return _handleCloseLong(_bondAmountClosed);
    }
}
