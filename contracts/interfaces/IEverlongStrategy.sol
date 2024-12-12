// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IUniV3Zap } from "hyperdrive/contracts/src/interfaces/IUniV3Zap.sol";
import { IEverlongEvents } from "./IEverlongEvents.sol";
import { IPermissionedStrategy } from "./IPermissionedStrategy.sol";

interface IEverlongStrategy is IPermissionedStrategy, IEverlongEvents {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                STRUCTS                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Contains the information needed to identify an open Hyperdrive
    ///         position.
    struct EverlongPosition {
        /// @notice Time when the position matures.
        uint128 maturityTime;
        /// @notice Amount of bonds in the position.
        uint128 bondAmount;
    }

    /// @notice Configuration on how the strategy's `asset` is converted to and
    ///         from a token used by the hyperdrive instance.
    struct ZapConfig {
        /// @notice Whether to use hyperdrive's base token. If false, use the
        ///         vault shares token.
        bool asBase;
        /// @notice Contract to use for zaps.
        address zap;
        /// @notice A flag that indicates whether or not the source token should
        ///         be wrapped into the input token. Uniswap v3 demands complete
        ///         precision on the input token amounts, which makes it hard to
        ///         work with rebasing tokens that have imprecise transfer
        ///         functions. Wrapping tokens provides a workaround for these
        ///         issues.
        bool shouldWrap;
        /// @notice A flag that indicates whether or not the Hyperdrive vault
        ///         shares token is a vault shares token. This is used to ensure
        ///         that the input into Hyperdrive properly handles rebasing
        ///         tokens.
        bool isRebasing;
        /// @notice Amount of time in seconds before the input zap expires.
        uint64 inputExpiry;
        /// @notice Amount of time in seconds before the output zap expires.
        uint64 outputExpiry;
        /// @notice Path for the zap from strategy to hyperdrive.
        bytes inputPath;
        /// @notice Path for the zap from hyperdrive to the strategy.
        bytes outputPath;
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

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                SETTERS                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Sets the temporary tend configuration. Necessary for `tend()`
    ///         call to succeed. Must be called in the same tx as `tend()`.
    function setTendConfig(TendConfig memory _config) external;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                ERRORS                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    error InvalidZapContract();
    error InvalidZapInputExpiry();
    error InvalidZapOutputExpiry();
    error InvalidZapInputPath();
    error InvalidZapOutputPath();

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 VIEWS                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Gets whether Everlong uses hyperdrive's base token.
    /// @return True if using hyperdrive's base token, false otherwise.
    function asBase() external view returns (bool);

    /// @notice Weighted average maturity timestamp of the portfolio.
    /// @return Weighted average maturity timestamp of the portfolio.
    function avgMaturityTime() external view returns (uint128);

    /// @notice Calculates the current value of Everlong's bond portfolio.
    /// @dev The result of this calculation is used to set the new totalAssets
    ///      in `_harvestAndReport`.
    function calculatePortfolioValue() external view returns (uint256);

    /// @notice Returns whether Everlong has sufficient idle liquidity to open
    ///         a new position.
    /// @return True if a new position can be opened, false otherwise.
    function canOpenPosition() external view returns (bool);

    /// @notice Reads and returns the current tend configuration from transient
    ///         storage.
    /// @return tendEnabled Whether TendConfig has been set.
    /// @return The current tend configuration.
    function getTendConfig()
        external
        returns (bool tendEnabled, IEverlongStrategy.TendConfig memory);

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
    function positionAt(
        uint256 _index
    ) external view returns (EverlongPosition memory);

    /// @notice Gets the number of positions managed by the Everlong instance.
    /// @return The number of positions.
    function positionCount() external view returns (uint256);

    /// @notice Total quantity of bonds held in the portfolio.
    /// @return Total quantity of bonds held in the portfolio.
    function totalBonds() external view returns (uint128);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure returns (string memory);

    /// @notice Returns whether zaps are used to interact with hyperdrive.
    /// @return True if zaps are used, false otherwise.
    function zapEnabled() external view returns (bool);
}
