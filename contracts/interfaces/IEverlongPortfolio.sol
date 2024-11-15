// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IEverlongStrategy } from "./IEverlongStrategy.sol";

interface IEverlongPortfolio {
    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Rebalances the Everlong bond portfolio if needed.
    /// @param _options Options to control the rebalance behavior.
    function rebalance(
        IEverlongStrategy.RebalanceOptions memory _options
    ) external;

    /// @notice Closes mature positions in the Everlong portfolio.
    /// @param _limit The maximum number of positions to close.
    /// @return output Amount of assets received from the closed positions.
    function closeMaturedPositions(
        uint256 _limit
    ) external returns (uint256 output);

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Gets the number of positions managed by the Everlong instance.
    /// @return The number of positions.
    function positionCount() external view returns (uint256);

    /// @notice Gets the position at an index.
    ///         Position `maturityTime` increases with each index.
    /// @param _index The index of the position.
    /// @return The position.
    function positionAt(
        uint256 _index
    ) external view returns (IEverlongStrategy.Position memory);

    /// @notice Determines whether any positions are matured.
    /// @return True if any positions are matured, false otherwise.
    function hasMaturedPositions() external view returns (bool);

    /// @notice Weighted average maturity timestamp of the portfolio.
    /// @return Weighted average maturity timestamp of the portfolio.
    function avgMaturityTime() external view returns (uint128);

    /// @notice Total quantity of bonds held in the portfolio.
    /// @return Total quantity of bonds held in the portfolio.
    function totalBonds() external view returns (uint128);

    /// @notice Determines whether Everlong's portfolio can currently be rebalanced.
    /// @return True if the portfolio can be rebalanced, false otherwise.
    function canRebalance() external view returns (bool);

    /// @notice Returns whether Everlong has sufficient idle liquidity to open
    ///         a new position.
    /// @return True if a new position can be opened, false otherwise.
    function canOpenPosition() external view returns (bool);

    /// @notice Returns the target percentage of idle liquidity to maintain.
    /// @dev Expressed as a fraction of ONE.
    /// @return The target percentage of idle liquidity to maintain.
    function targetIdleLiquidityPercentage() external view returns (uint256);

    /// @notice Returns the max percentage of idle liquidity to maintain.
    /// @dev Expressed as a fraction of ONE.
    /// @return The max percentage of idle liquidity to maintain.
    function maxIdleLiquidityPercentage() external view returns (uint256);

    /// @notice Returns the target amount of idle liquidity to maintain.
    /// @dev Expressed in assets.
    /// @return The target amount of idle liquidity to maintain.
    function targetIdleLiquidity() external view returns (uint256);

    /// @notice Returns the max amount of idle liquidity to maintain.
    /// @dev Expressed in assets.
    /// @return The max amount of idle liquidity to maintain.
    function maxIdleLiquidity() external view returns (uint256);

    /// @notice Amount of additional bonds to close during a partial position
    ///         closure to avoid rounding errors. Represented as a percentage
    ///         of the positions total  amount of bonds where 0.1e18 represents
    ///         a 10% buffer.
    /// @return The buffer for partial position closures.
    function partialPositionClosureBuffer() external view returns (uint256);
}
