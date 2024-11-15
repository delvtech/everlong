// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";
import { IEverlongEvents } from "./IEverlongEvents.sol";
import { IEverlongPortfolio } from "./IEverlongPortfolio.sol";

interface IEverlongStrategy is IStrategy, IEverlongEvents, IEverlongPortfolio {
    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Structs                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Contains the information needed to identify an open Hyperdrive position.
    struct Position {
        /// @notice Time when the position matures.
        uint128 maturityTime;
        /// @notice Amount of bonds in the position.
        uint128 bondAmount;
    }

    // TODO: Revisit position closure limit to see what POSITION_DURATION would
    //       be needed to run out of gas.
    //
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
    // │                                 Views                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Gets the address of the underlying Hyperdrive Instance
    function hyperdrive() external view returns (address);

    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external pure returns (string memory);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure returns (string memory);

    /// @notice Gets whether Everlong uses hyperdrive's base token.
    /// @return True if using hyperdrive's base token, false otherwise.
    function asBase() external view returns (bool);
}
