// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { DebtAllocator } from "vault-periphery/debtAllocators/DebtAllocator.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { BaseStrategy, ERC20 } from "tokenized-strategy/BaseStrategy.sol";
import { IEverlongStrategy } from "./interfaces/IEverlongStrategy.sol";
import { EVERLONG_STRATEGY_KEEPER_KIND, EVERLONG_VERSION, ONE } from "./libraries/Constants.sol";
import { HyperdriveExecutionLibrary } from "./libraries/HyperdriveExecution.sol";
import { Portfolio } from "./libraries/Portfolio.sol";
import { IRoleManager } from "./interfaces/IRoleManager.sol";
import { CommonReportTrigger } from "lib/vault-periphery/lib/tokenized-strategy-periphery/src/ReportTrigger/CommonReportTrigger.sol";
import { IVault } from "yearn-vaults-v3/interfaces/IVault.sol";
import { Roles } from "yearn-vaults-v3/interfaces/Roles.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IStrategy } from "tokenized-strategy/interfaces/IStrategy.sol";

/// @author DELV
/// @title EverlongStrategyKeeper
/// @notice Periphery contract to simplify operations for keepers.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract EverlongStrategyKeeper is Ownable {
    using FixedPointMath for uint256;
    using HyperdriveExecutionLibrary for IHyperdrive;
    using Portfolio for Portfolio.State;
    using SafeCast for *;
    using SafeERC20 for ERC20;

    string constant name = "EverlongStrategyKeeper";

    string constant kind = EVERLONG_STRATEGY_KEEPER_KIND;

    string constant version = EVERLONG_VERSION;

    /// @notice Address of the target RoleManager contract.
    /// @dev Helpful for getting periphery contract addresses and enumerating
    ///      vaults.
    address roleManager;

    /// @notice Address of the external `CommonReportTrigger` contract.
    /// @dev This contract contains default checks for whether to report+tend.
    address trigger;

    /// @notice Initialize the EverlongStrategyKeeper contract.
    /// @param _trigger Address for the `CommonReportTrigger` contract.
    constructor(address _roleManager, address _trigger) Ownable(msg.sender) {
        roleManager = _roleManager;
        trigger = _trigger;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                Setters                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Updates the address of the CommonReportTrigger contract.
    /// @param _trigger Address of the CommonReportTrigger contract to set.
    function setTrigger(address _trigger) external onlyOwner {
        trigger = _trigger;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              Maintenance                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Calls `process_report()` on the vault/strategy combination if
    ///      needed.
    /// @param _vault Address of the vault contract to process the report on.
    /// @param _strategy Address of the strategy contract to process the report
    ///        on.
    function processReport(address _vault, address _strategy) public onlyOwner {
        // Bail if this contract doesn't have the REPORTING_MANAGER role.
        uint256 roleMap = IVault(_vault).roles(address(this));
        if (roleMap & Roles.REPORTING_MANAGER != roleMap) {
            return;
        }

        // Check if report should be called on the vault/strategy combination.
        (
            bool shouldReportVault,
            bytes memory vaultCalldataOrReason
        ) = CommonReportTrigger(trigger).defaultVaultReportTrigger(
                _vault,
                _strategy
            );

        // If process_report should be called, call it with the recommended
        // parameters.
        if (shouldReportVault) {
            (bool success, bytes memory err) = _vault.call(
                vaultCalldataOrReason
            );
            if (!success) {
                revert(
                    string.concat("vault process_report failed: ", string(err))
                );
            }
        }
    }

    /// @dev Calls `report()` on the strategy if needed.
    ///
    /// @param _strategy Address of the strategy contract to report on.
    /// @param _config Configuration for the `tend()` function called within
    ///        `_harvestAndReport()` in the strategy.
    function strategyReport(
        address _strategy,
        IEverlongStrategy.TendConfig memory _config
    ) public onlyOwner {
        // Bail if this contract isn't the keeper.
        if (IStrategy(_strategy).keeper() != address(this)) {
            return;
        }

        // Check if report should be called on the strategy.
        (
            bool shouldReportStrategy,
            bytes memory strategyCalldataOrReason
        ) = CommonReportTrigger(trigger).defaultStrategyReportTrigger(
                _strategy
            );

        // If report should be called, call it with the recommended parameters.
        if (shouldReportStrategy) {
            IEverlongStrategy(_strategy).setTendConfig(_config);
            (bool success, bytes memory err) = _strategy.call(
                strategyCalldataOrReason
            );
            if (!success) {
                revert(string.concat("strategy report failed: ", string(err)));
            }
        }
    }

    /// @dev Calls `tend()` on the strategy if needed and sets the
    ///      tend configuration.
    /// @param _strategy Address of the strategy to tend.
    /// @param _config Configuration for the tend call.
    function tend(
        address _strategy,
        IEverlongStrategy.TendConfig memory _config
    ) public onlyOwner {
        // Bail if this contract isn't the keeper.
        if (IStrategy(_strategy).keeper() != address(this)) {
            return;
        }

        // Check if tend should be called.
        (bool shouldTend, bytes memory calldataOrReason) = CommonReportTrigger(
            trigger
        ).strategyTendTrigger(_strategy);

        // If tend should be called, call it with the recommended parameters.
        if (shouldTend) {
            IEverlongStrategy(_strategy).setTendConfig(_config);
            (bool success, bytes memory err) = _strategy.call(calldataOrReason);
            if (!success) {
                revert(string.concat("strategy tend failed: ", string(err)));
            }
        }
    }

    /// @dev Calls `update_debt()` on the vault if needed.
    /// @param _vault Address of the vault to update debt for.
    /// @param _strategy Address of the strategy to update debt for.
    function update_debt(address _vault, address _strategy) public onlyOwner {
        // Get the DebtAllocator contract address.
        DebtAllocator debtAllocator = DebtAllocator(
            IRoleManager(roleManager).getDebtAllocator(_vault)
        );

        // Bail if there's no DebtAllocator for the vault or this contract isn't
        // the keeper.
        if (
            address(debtAllocator) == address(0) ||
            !debtAllocator.keepers(address(this))
        ) {
            revert("vault update debt failed: improper vault configuration");
        }

        // If update_debt should be called, call it with the recommended parameters.
        (bool shouldUpdateDebt, bytes memory calldataOrReason) = debtAllocator
            .shouldUpdateDebt(_vault, _strategy);
        if (shouldUpdateDebt) {
            (bool success, bytes memory err) = address(debtAllocator).call(
                calldataOrReason
            );
            if (!success) {
                revert(
                    string.concat("vault update debt failed: ", string(err))
                );
            }
        }
    }
}
