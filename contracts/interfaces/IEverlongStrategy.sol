// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";
import { IEverlongEvents } from "./IEverlongEvents.sol";

interface IEverlongStrategy is IStrategy, IEverlongEvents {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                STRUCTS                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Contains the information needed to identify an open Hyperdrive
    ///         position.
    struct Position {
        /// @notice Time when the position matures.
        uint128 maturityTime;
        /// @notice Amount of bonds in the position.
        uint128 bondAmount;
    }

    /// @notice Configuration for how `tend()` will be performed.
    struct TendConfig {
        /// @notice Minimum amount of bonds to receive when opening a position.
        uint256 minOutput;
        /// @notice Minimum vault share price when opening a position.
        uint256 minVaultSharePrice;
        /// @notice Maximum amount of mature positions that can be closed.
        /// @dev A value of zero indicates no limit.
        uint256 positionClosureLimit;
        /// @notice Passed to hyperdrive `openLong()` and `closeLong()`.
        bytes extraData;
    }

    /// @notice Parameters to specify how a rebalance will be performed.
    struct RebalanceOptions {
        /// @notice Limit on the amount of idle to spend on a new position.
        /// @dev A value of zero indicates no limit.
        uint256 spendingLimit;
        /// @notice Minimum amount of bonds to receive when opening a position.
        uint256 minOutput;
        /// @notice Minimum vault share price when opening a position.
        uint256 minVaultSharePrice;
        /// @notice Maximum amount of mature positions that can be closed.
        /// @dev A value of zero indicates no limit.
        uint256 positionClosureLimit;
        /// @notice Passed to hyperdrive `openLong()` and `closeLong()`.
        bytes extraData;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                SETTERS                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Sets the minimum number of bonds to receive when opening a long.
    /// @param _minOutput Minimum number of bonds to receive when opening a long.
    function setMinOutput(uint256 _minOutput) external;

    /// @notice Sets the minimum vault share price when opening a long.
    /// @param _minVaultSharePrice Minimum vault share price when opening a long.
    function setMinVaultSharePrice(uint256 _minVaultSharePrice) external;

    /// @notice Sets the max amount of mature positions to close at a time.
    /// @param _positionClosureLimit Max amount of mature positions to close at
    ///        a time.
    function setPositionClosureLimit(uint256 _positionClosureLimit) external;

    /// @notice Sets the extra data to pass to hyperdrive when opening/closing
    ///         longs.
    /// @param _extraData Extra data to pass to hyperdrive when opening/closing
    ///         longs.
    function setExtraData(bytes memory _extraData) external;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 VIEWS                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Gets whether Everlong uses hyperdrive's base token.
    /// @return True if using hyperdrive's base token, false otherwise.
    function asBase() external view returns (bool);

    /// @notice Weighted average maturity timestamp of the portfolio.
    /// @return Weighted average maturity timestamp of the portfolio.
    function avgMaturityTime() external view returns (uint128);

    /// @notice Calculates the current totalAssets.
    /// @dev The result of this calculation is used to set the new totalAssets
    ///      is `_harvestAndReport`.
    function calculateTotalAssets() external view returns (uint256);

    /// @notice Returns whether Everlong has sufficient idle liquidity to open
    ///         a new position.
    /// @return True if a new position can be opened, false otherwise.
    function canOpenPosition() external view returns (bool);

    /// @notice Gets the minimum number of bonds to receive when opening a long.
    /// @return Minimum number of bonds to receive when opening a long.
    function getMinOutput() external view returns (uint256);

    /// @notice Gets the minimum vault share price when opening a long.
    /// @return Minimum vault share price when opening a long.
    function getMinVaultSharePrice() external view returns (uint256);

    /// @notice Gets the max amount of mature positions to close at a time.
    /// @return Max amount of mature positions to close at a time.
    function getPositionClosureLimit() external view returns (uint256);

    /// @notice Gets the extra data to pass to hyperdrive when opening/closing
    ///         longs.
    /// @return Extra data to pass to hyperdrive when opening/closing longs.
    function getExtraData() external view returns (bytes memory);

    /// @notice Determines whether any positions are matured.
    /// @return True if any positions are matured, false otherwise.
    function hasMaturedPositions() external view returns (bool);

    /// @notice Gets the address of the underlying Hyperdrive Instance
    function hyperdrive() external view returns (address);

    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external pure returns (string memory);

    /// @notice Amount of additional bonds to close during a partial position
    ///         closure to avoid rounding errors. Represented as a percentage
    ///         of the positions total  amount of bonds where 1e18 represents
    ///         a 100% buffer.
    /// @return The buffer for partial position closures.
    function partialPositionClosureBuffer() external view returns (uint256);

    /// @notice Gets the position at an index.
    ///         Position `maturityTime` increases with each index.
    /// @param _index The index of the position.
    /// @return The position.
    function positionAt(uint256 _index) external view returns (Position memory);

    /// @notice Gets the number of positions managed by the Everlong instance.
    /// @return The number of positions.
    function positionCount() external view returns (uint256);

    /// @notice Total quantity of bonds held in the portfolio.
    /// @return Total quantity of bonds held in the portfolio.
    function totalBonds() external view returns (uint128);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure returns (string memory);
}
