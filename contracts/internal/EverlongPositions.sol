// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { IEverlong } from "../interfaces/IEverlong.sol";
import { IEverlongPositions } from "../interfaces/IEverlongPositions.sol";
import { Portfolio } from "../libraries/Portfolio.sol";
import { EverlongBase } from "./EverlongBase.sol";

/// @author DELV
/// @title EverlongPositions
/// @notice Everlong bond position management.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongPositions is EverlongBase, IEverlongPositions {
    using Portfolio for Portfolio.State;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongPositions
    function rebalance() external {
        _rebalance();
    }

    /// @dev Rebalances the Everlong bond portfolio if needed.
    function _rebalance() internal override {
        // Close all mature positions (if present) so that the proceeds can be
        // used to purchase longs.
        if (hasMaturedPositions()) {
            _closeMaturedPositions();
        }

        // Spend Everlong's excess idle liquidity (if sufficient) on opening a long.
        if (hasSufficientExcessLiquidity()) {
            _spendExcessLiquidity();
        }

        // Emit the `Rebalanced()` event.
        emit Rebalanced();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Virtual                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    // TODO: Implement idle liquidity and possibly remove.
    /// @dev Calculates the amount of excess liquidity that can be spent opening longs.
    /// @dev Can be overridden by child contracts.
    /// @return Amount of excess liquidity that can be spent opening longs.
    function _excessLiquidity() internal view virtual returns (uint256) {
        // Return the current balance of the contract.
        return IERC20(_asset).balanceOf(address(this));
    }

    // TODO: Come up with a safer value or remove.
    /// @dev Calculates the minimum `openLong` output from Hyperdrive
    ///       given the amount of capital being spend.
    /// @dev Can be overridden by child contracts.
    /// @param _amount Amount of capital provided for `openLong`.
    /// @return Minimum number of bonds to receive from `openLong`.
    function _minOpenLongOutput(
        uint256 _amount
    ) internal view virtual returns (uint256) {
        return 0;
    }

    // TODO: Come up with a safer value or remove.
    /// @dev Calculates the minimum vault share price at which to
    ///      open the long.
    /// @dev Can be overridden by child contracts.
    /// @param _amount Amount of capital provided for `openLong`.
    /// @return minimum vault share price for `openLong`.
    function _minVaultSharePrice(
        uint256 _amount
    ) internal view virtual returns (uint256) {
        return 0;
    }

    // TODO: Come up with a safer value or remove.
    /// @dev Calculates the minimum proceeds Everlong will accept for
    ///      closing the long.
    /// @dev Can be overridden by child contracts.
    /// @param _maturityTime Maturity time of the long to close.
    /// @param _bondAmount Amount of bonds to close.
    function _minCloseLongOutput(
        uint256 _maturityTime,
        uint256 _bondAmount
    ) internal view returns (uint256) {
        return 0;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Opening (Internal)                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Spend the excess idle liquidity for the Everlong contract.
    /// @dev Can be overridden by implementing contracts to configure
    ///      how much idle to spend and how it is spent.
    function _spendExcessLiquidity() internal {
        // Open the long position with the available excess liquidity.
        // TODO: Worry about slippage.
        // TODO: Ensure amount < maxLongAmount
        // TODO: Idle liquidity implementation
        uint256 _amount = _excessLiquidity();
        IERC20(_asset).approve(_hyperdrive, _amount);
        uint256 vaultSharePrice = _hyperdriveVaultSharePrice();
        (uint256 maturityTime, uint256 bondAmount) = IHyperdrive(_hyperdrive)
            .openLong(
                _amount,
                _minOpenLongOutput(_amount),
                _minVaultSharePrice(_amount),
                IHyperdrive.Options(address(this), _asBase, "")
            );

        // Update accounting to reflect the newly opened long.
        _portfolio.handleOpenPosition(
            maturityTime,
            bondAmount,
            vaultSharePrice
        );
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Position Closing (Internal)                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc EverlongBase
    function _increaseIdle(
        uint256 _target
    ) internal override returns (uint256 idle) {
        // Obtain the current amount of idle held by Everlong and return if
        // it is above the target.
        idle = IERC20(_asset).balanceOf(address(this));
        if (idle >= _target) {
            return idle;
        }

        // Close all matured positions and return if updated idle is above
        // the target.
        idle += _closeMaturedPositions();
        if (idle >= _target) {
            return idle;
        }

        // Close immature positions from oldest to newest until idle is
        // above the target.
        uint256 positionCount = _portfolio.positionCount();
        IEverlong.Position memory position;
        while (positionCount > 0) {
            position = _portfolio.head();

            // Close the position and add output to the current idle.
            idle += IHyperdrive(_hyperdrive).closeLong(
                position.maturityTime,
                position.bondAmount,
                _minCloseLongOutput(position.maturityTime, position.bondAmount),
                IHyperdrive.Options(address(this), _asBase, "")
            );

            // Update accounting for the closed position.
            _portfolio.handleClosePosition();

            // Return if the updated idle is above the target.
            if (idle >= _target) {
                return idle;
            }

            positionCount--;
        }

        // Revert since all positions are closed and the target idle is
        // has not been met;
        revert IEverlong.TargetIdleTooHigh();
    }

    /// @dev Close all matured positions.
    /// @return output Output received from closing the positions.
    function _closeMaturedPositions() internal returns (uint256 output) {
        // Loop through mature positions and close them all.
        // TODO: Enable closing of mature positions incrementally to avoid
        //       the case where the # of mature positions exceeds the max
        //       gas per block.
        IEverlong.Position memory _position;
        while (hasMaturedPositions()) {
            // Retrieve the oldest matured position and close it.
            _position = getPosition(0);
            output += IHyperdrive(_hyperdrive).closeLong(
                _position.maturityTime,
                _position.bondAmount,
                _minCloseLongOutput(
                    _position.maturityTime,
                    _position.bondAmount
                ),
                IHyperdrive.Options(address(this), _asBase, "")
            );

            // Update positions to reflect the newly closed long.
            _portfolio.handleClosePosition();
        }
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc IEverlongPositions
    function getPositionCount() public view returns (uint256) {
        return _portfolio.positionCount();
    }

    /// @inheritdoc IEverlongPositions
    function getPosition(
        uint256 _index
    ) public view returns (IEverlong.Position memory position) {
        position = _portfolio.at(_index);
    }

    /// @inheritdoc IEverlongPositions
    function hasMaturedPositions() public view returns (bool) {
        // Return false if there are no positions.
        if (_portfolio.isEmpty()) return false;

        // Return true if the current block timestamp is after
        // the oldest position's `maturityTime`.
        return (_portfolio.head()).maturityTime <= block.timestamp;
    }

    /// @inheritdoc IEverlongPositions
    function hasSufficientExcessLiquidity() public view returns (bool) {
        // Return whether the current excess liquidity is greater than
        // Hyperdrive's minimum transaction amount.
        return
            _excessLiquidity() >=
            IHyperdrive(_hyperdrive).getPoolConfig().minimumTransactionAmount;
    }

    // TODO: Consider storing hyperdrive's minimumTransactionAmount.
    /// @inheritdoc IEverlongPositions
    function canRebalance() public view returns (bool) {
        return hasMaturedPositions() || hasSufficientExcessLiquidity();
    }

    /// @dev Returns the current vaultSharePrice of the hyperdrive instance.
    /// @return The hyperdrive's vaultSharePrice.
    function _hyperdriveVaultSharePrice() internal view returns (uint256) {
        return IHyperdrive(_hyperdrive).convertToBase(1e18);
    }
}
