// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { ERC4626 } from "solady/tokens/ERC4626.sol";
import { IEverlongAdmin } from "./IEverlongAdmin.sol";
import { IEverlongEvents } from "./IEverlongEvents.sol";
import { IEverlongPortfolio } from "./IEverlongPortfolio.sol";

abstract contract IEverlong is
    ERC4626,
    IEverlongAdmin,
    IEverlongEvents,
    IEverlongPortfolio
{
    // ╭─────────────────────────────────────────────────────────╮
    // │ Structs                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Contains the information needed to identify an open Hyperdrive position.
    struct Position {
        /// @notice Time when the position matures.
        uint128 maturityTime;
        /// @notice Amount of bonds in the position.
        uint128 bondAmount;
    }

    // TODO: Revisit position closure limit to see what position duration would
    //       be needed to run out of gas.
    /// @notice Parameters to specify how a rebalance will be performed.
    struct RebalanceOptions {
        uint256 spendingOverride;
        uint256 minOutput;
        uint256 minVaultSharePrice;
        uint256 positionClosureLimit;
        bytes extraData;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Gets the address of the underlying Hyperdrive Instance
    function hyperdrive() external view virtual returns (address);

    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external pure virtual returns (string memory);

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external pure virtual returns (string memory);

    // ╭─────────────────────────────────────────────────────────╮
    // │ Errors                                                  │
    // ╰─────────────────────────────────────────────────────────╯

    // ── Admin ──────────────────────────────────────────────────

    /// @notice Thrown when caller is not the admin.
    error Unauthorized();

    // ── Idle Liquidity ─────────────────────────────────────────

    /// @notice Thrown when a percentage value is too large (>1e18).
    error PercentageTooLarge();

    /// @notice Thrown when target is greater than max.
    error TargetIdleGreaterThanMax();

    /// @notice Thrown when a redemption results in zero output assets.
    error RedemptionZeroOutput();

    // ── Rebalancing ────────────────────────────────────────────

    /// @notice Thrown when the spending override is below hyperdrive's
    ///         minimum transaction amount.
    error SpendingOverrideTooLow();

    /// @notice Thrown when the spending override is above the difference
    ///         between Everlong's balance and its max idle liquidity.
    error SpendingOverrideTooHigh();
}
