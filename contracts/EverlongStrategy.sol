// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { BaseStrategy, ERC20 } from "tokenized-strategy/BaseStrategy.sol";
import { IEverlongStrategy } from "./interfaces/IEverlongStrategy.sol";
import { EVERLONG_STRATEGY_KIND, EVERLONG_VERSION, ONE } from "./libraries/Constants.sol";
import { EverlongPortfolioLibrary } from "./libraries/EverlongPortfolio.sol";
import { HyperdriveExecutionLibrary } from "./libraries/HyperdriveExecution.sol";

//           ,---..-.   .-.,---.  ,---.   ,-.    .---.  .-. .-.  ,--,
//           | .-' \ \ / / | .-'  | .-.\  | |   / .-. ) |  \| |.' .'
//           | `-.  \ V /  | `-.  | `-'/  | |   | | |(_)|   | ||  |  __
//           | .-'   ) /   | .-'  |   (   | |   | | | | | |\  |\  \ ( _)
//           |  `--.(_)    |  `--.| |\ \  | `--.\ `-' / | | |)| \  `-) )
//           /( __.'       /( __.'|_| \)\ |( __.')---'  /(  (_) )\____/
//          (__)          (__)        (__)(_)   (_)    (__)    (__)
//
//          ##########      #++###################################      ### ######
//              ##########  #####################################   ###########
//                  #########################################################
//                  ##+###################################################
//                   ###############################################
//                   ##+#########++++++++++++++++++################
//                    ##+#####+++++++++++++++++++++++++++#########+
//                   +#######++++++++++++++++++++++++++++++######
//      ####################++++++++++++++++++++++++++++++++++#####
//   #####+# #+############++++++++++++++++++++++++++++++++++++##############
// ##+    ++##############+++++++++++++++++++++++++++++++++-++++###################
// ######################++++++++++++++++++++++++++++++++++-++++##########  ####+ #
// +#++++###############++++++++++#######++++++++++++++++++++++++#######      #####
//     +########+######++++++++++++++++++++++++++++++++++++++++++####           ###
//    ####  ###########++++++--+++++##++++++++++++++##+++++++++++####             #
//  +#################+++++--+++++++###+#++++++++++++####++++++++#######
// +##################++++++++++++++++++##+++++++++++###+++++++++#########
// ##################++++++++++++++++++++++++++++++++++###+++++++###############
// ##################++-+++++++++++++++++++++++++++++++##+++++++###################
//   ###    #####++++++-++++++++++++++++++++++++++++++++++++++++##########  #######
//  ###      ###+++++++++---+++++++++++++++-+++-++++++++++++++++######### #########
//          ###++++++++------++++++++++++###++-++++++++--+++++++#############
//        #####+++++++----------+++++++++++++++##++++-------+++##########
//    #########++++++----------+++++++++++++++++++++++------+++#########
// #############+++++----------+++++++++++++++++++++++++---+++###########
// #############++-++----------+++++++++++++++++++++++-+---++###    ## ###
// ### ###       ++++----------+++++++-++-++++++-+++++-----++###        ###
//                 ++----------+++#+++---------+++--++-+---++#####       ####
//                #+----------+++++++++++++--+--+++-------+-++#####       ####
//              ####+---------++++++++++++++++++#+++-----++-++#######      ####
//            ######+----------------++++++++++++++-----++--+    #####       ###
//          ##### #+++------+++-------+++++++--+++-----++-###       ###      #####
//         ###    ++--+-----+++++++++++++---------+---++-##++###    +##
//        ##+   ###+--------+++++++++++++++++--+++---++++      ++#######
//     ####+    ###+-----------+++++++++++++++++++++++++            #  #
//           ++##++++---------------+++++++++++++++++
//          ++## +++++------------+++++++++++++++++++
//              +++++++-----------+++++++++++++++++++
//          ++###++++++---------------++++++++++++++
//       +++#####+++++++++--------------++++++++++++
// #+ +++#######+++++++++++---------------+++++++++#+
// ###########++++++++++++++-------------++++++++++###
//
/// @author DELV
/// @title EverlongStrategy
/// @notice A money market powered by Hyperdrive and Yearn.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract EverlongStrategy is BaseStrategy {
    using FixedPointMath for uint256;
    using HyperdriveExecutionLibrary for IHyperdrive;
    using EverlongPortfolioLibrary for EverlongPortfolioLibrary.State;
    using SafeCast for *;
    using SafeERC20 for ERC20;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                        Transient Storage Slots                        │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice TEND_ENABLED transient storage slot key.
    /// @dev The value at this slot must be set for `tend(..)` to be executed.
    bytes32 constant TEND_ENABLED_SLOT_KEY =
        keccak256(abi.encode("TEND_ENABLED"));

    /// @notice TendConfig.minOutput transient storage slot key.
    bytes32 constant MIN_OUTPUT_SLOT_KEY = keccak256(abi.encode("MIN_OUTPUT"));

    /// @notice TendConfig.minVaultSharePrice transient storage slot key.
    bytes32 constant MIN_VAULT_SHARE_PRICE_SLOT_KEY =
        keccak256(abi.encode("MIN_VAULT_SHARE_PRICE"));

    /// @notice TendConfig.positionClosureLimit transient storage slot key.
    bytes32 constant POSITION_CLOSURE_LIMIT_SLOT_KEY =
        keccak256(abi.encode("POSITION_CLOSURE_LIMIT"));

    /// @notice TendConfig.extraData transient storage slot key.
    bytes32 constant EXTRA_DATA_SLOT_KEY = keccak256(abi.encode("EXTRA_DATA"));

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                       Constants and Immutables                        │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Amount of additional bonds to close during a partial position
    ///         closure to avoid rounding errors. Represented as a percentage
    ///         of the positions total  amount of bonds where 1e18 represents
    ///         a 100% buffer.
    uint256 public constant partialPositionClosureBuffer = 0.001e18;

    /// @notice The Everlong instance's kind.
    string public constant kind = EVERLONG_STRATEGY_KIND;

    /// @notice The Everlong instance's version.
    string public constant version = EVERLONG_VERSION;

    /// @notice Address of the Hyperdrive instance wrapped by Everlong.
    address public immutable hyperdrive;

    /// @notice Whether to use Hyperdrive's base token to purchase bonds.
    ///         If false, use the Hyperdrive's `vaultSharesToken`.
    bool public immutable asBase;

    /// @dev The Hyperdrive's PoolConfig.
    IHyperdrive.PoolConfig internal _poolConfig;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 State                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Structure to store and account for everlong-controlled positions.
    EverlongPortfolioLibrary.State internal _portfolio;

    /// @dev Mapping to store valid depositors. Used to limit interactions with
    ///      this strategy to only approved vaults.
    ///
    /// @dev Depositors are restricted since this strategy is intended to be
    ///      deployed with a `profitMaxUnlockTime` of zero which is manipulable
    ///      if non-vaults are allowed to interact.
    mapping(address => bool) internal _depositors;

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              Constructor                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Creates a new EverlongStrategy.
    /// @param _asset Asset to use for the strategy.
    /// @param __name Name for the strategy.
    /// @param _hyperdrive Address of the Hyperdrive instance.
    /// @param _asBase Whether `_asset` is Hyperdrive's base asset.
    constructor(
        address _asset,
        string memory __name,
        address _hyperdrive,
        bool _asBase
    ) BaseStrategy(_asset, __name) {
        hyperdrive = _hyperdrive;
        asBase = _asBase;
        _poolConfig = IHyperdrive(_hyperdrive).getPoolConfig();
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                             Permissioning                             │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Enable or disable deposits to the strategy `_depositor`.
    /// @dev Can only be called by the strategy's `Management` address.
    /// @param _depositor Address to enable/disable deposits for.
    function setDepositor(
        address _depositor,
        bool _enabled
    ) external onlyManagement {
        _depositors[_depositor] = _enabled;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                        TokenizedStrategy Hooks                        │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Deploy up to '_amount' of 'asset' in the yield source.
    /// @param . The amount of 'asset' that the strategy can attempt
    ///        to deposit in the yield source.
    function _deployFunds(uint256) internal pure override {
        // Do nothing.
        // Opening longs on Hyperdrive is sandwichable so funds should only be
        // deployed when the `keeper` calls `tend()`.
        return;
    }

    /// @dev Attempt to free the '_amount' of 'asset'.
    ///      - Any difference between `_amount` and what is actually freed will be
    ///        counted as a loss and passed on to the withdrawer.
    ///      - Unrealized losses must be calculated and proportionally
    ///        applied to the withdrawer.
    /// @param _amount The amount of 'asset' to be freed.
    function _freeFunds(uint256 _amount) internal override {
        // The redeemer's proportional share of the portfolio losses is as
        // follows (assuming losses have occurred):
        //
        //   ∆P         : Total portfolio losses.
        //   ∆P_r       : Redeemer's loss share.
        //   _amount    : Value of funds to free.
        //   TA_p       : Previous stored `totalAssets`.
        //
        //   ∆P_r  = (∆P * _amount) / TA_p
        //
        // Unfortunately totalAssets is a combination of portfolio value and
        // idle assets, so we don't know the proportions of each. This would be
        // hugely problematic if idle liquidity varied dramatically, but it
        // doesn't.
        //
        // For our case, the strategy will almost always have zero idle except
        // right after a redemption (due to the partialPositionClosureBuffer).
        // Also, the maximum amount of idle the strategy can have for any
        // extended period is Hyperdrive's minimumTransactionAmount.
        //
        // Since idle liquidity won't vary greatly and has little effect on
        // totalAssets it's likely safe for us to simply use totalAssets to
        // determine and attribute losses.

        // Calculate the current `totalAssets` and retrieve the previous value.
        uint256 idle = asset.balanceOf(address(this));
        uint256 currentTotalAssets = calculatePortfolioValue() + idle;
        uint256 previousTotalAssets = TokenizedStrategy.totalAssets();

        // If the current `totalAssets` is less than the previous, there are
        // unrealized losses.
        if (currentTotalAssets < previousTotalAssets) {
            // Calculate the withdrawer's proportion of losses.
            //
            // It's important to use only the value of longs being closed, not
            // the total amount being freed, when calculating the withdrawer's
            // share.
            //
            //     totalWithdrawalAmount = _amount + idle
            //
            uint256 loss = previousTotalAssets - currentTotalAssets;
            uint256 proportionalLoss = (loss).mulDivDown(
                _amount,
                previousTotalAssets
            );
            _amount -= proportionalLoss;
        }

        // Close positions until `_amount` is reached.
        _closePositions(_amount);
    }

    /// @dev Internal function to harvest all rewards, redeploy any idle
    ///      funds and return an accurate accounting of all funds currently
    ///      held by the Strategy.
    /// @return _totalAssets A trusted and accurate account for the total
    ///         amount of 'asset' the strategy currently holds including idle
    ///         funds.
    function _harvestAndReport()
        internal
        override
        returns (uint256 _totalAssets)
    {
        // If the strategy isn't shut down, call `_tend()` to close mature
        // positions and spend idle if needed.
        if (!TokenizedStrategy.isShutdown() && _tendTrigger()) {
            _tend(asset.balanceOf(address(this)));
        }

        // Recalculate the value of assets the strategy controls.
        _totalAssets =
            calculatePortfolioValue() +
            asset.balanceOf(address(this));
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                              Maintenance                              │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Can be called inbetween reports to rebalance the portfolio.
    /// @param _totalIdle The current amount of idle funds that are available to
    ///         deploy.
    function _tend(uint256 _totalIdle) internal override {
        // Read the TendConfig from transient storage.
        (
            bool tendEnabled,
            IEverlongStrategy.TendConfig memory tendConfig
        ) = getTendConfig();

        // If TendConfig hasn't been set, don't run the tend.
        if (!tendEnabled) {
            return;
        }

        // Close matured positions.
        _totalIdle += _closeMaturedPositions(tendConfig.positionClosureLimit);

        // Limit the amount that can be spent by the deposit limit.
        uint256 toSpend = _totalIdle.min(availableDepositLimit(address(this)));

        // If Everlong has sufficient idle, open a new position.
        if (toSpend > _poolConfig.minimumTransactionAmount) {
            // Approve leaving an extra wei so the slot stays warm.
            ERC20(asset).forceApprove(address(hyperdrive), toSpend + 1);
            (uint256 maturityTime, uint256 bondAmount) = IHyperdrive(hyperdrive)
                .openLong(
                    asBase,
                    toSpend,
                    tendConfig.minOutput,
                    tendConfig.minVaultSharePrice,
                    tendConfig.extraData
                );

            // Account for the new position in the portfolio.
            _portfolio.handleOpenPosition(maturityTime, bondAmount);
        }
    }

    /// @dev Trigger to override if tend() will be used by the strategy.
    ///      This must be implemented if the strategy hopes to invoke _tend().
    ///
    /// @return Return true if tend() should be called by keeper, false if not.
    function _tendTrigger() internal view override returns (bool) {
        return hasMaturedPositions() || canOpenPosition();
    }

    /// @notice Sets the temporary tend configuration. Will only persist through
    ///         the duration of the transaction. Must be called in the same tx
    ///         as `tend()`.
    function setTendConfig(
        IEverlongStrategy.TendConfig memory _config
    ) external onlyKeepers {
        // Calculate the slots where each part of the `TendConfig` are stored.
        bytes32 tendEnabledSlot = TEND_ENABLED_SLOT_KEY;
        bytes32 minOutputSlot = MIN_OUTPUT_SLOT_KEY;
        bytes32 minVaultSharePriceSlot = MIN_VAULT_SHARE_PRICE_SLOT_KEY;
        bytes32 positionClosureLimitSlot = POSITION_CLOSURE_LIMIT_SLOT_KEY;
        bytes32 extraDataSlot = EXTRA_DATA_SLOT_KEY;

        // Set the flag indicating that TendConfig has been set.
        // Store each part of the TendConfig in transient storage.
        uint256 minOutput = _config.minOutput;
        uint256 minVaultSharePrice = _config.minVaultSharePrice;
        uint256 positionClosureLimit = _config.positionClosureLimit;
        bytes memory extraData = _config.extraData;
        assembly {
            tstore(tendEnabledSlot, 1)
            tstore(minOutputSlot, minOutput)
            tstore(minVaultSharePriceSlot, minVaultSharePrice)
            tstore(positionClosureLimitSlot, positionClosureLimit)
            tstore(extraDataSlot, extraData)
        }
    }

    /// @notice Reads and returns the current tend configuration from transient
    ///         storage.
    /// @return tendEnabled Whether or not TendConfig has been set.
    /// @return . The current tend configuration.
    function getTendConfig()
        public
        view
        returns (bool tendEnabled, IEverlongStrategy.TendConfig memory)
    {
        // Calculate the slots where each part of the `TendConfig` are stored.
        bytes32 tendEnabledSlot = TEND_ENABLED_SLOT_KEY;
        bytes32 minOutputSlot = MIN_OUTPUT_SLOT_KEY;
        bytes32 minVaultSharePriceSlot = MIN_VAULT_SHARE_PRICE_SLOT_KEY;
        bytes32 positionClosureLimitSlot = POSITION_CLOSURE_LIMIT_SLOT_KEY;

        // Load each part of the TendConfig from transient storage.
        // If the TendConfig hasn't been set, revert.
        bytes32 extraDataSlot = EXTRA_DATA_SLOT_KEY;
        uint256 minOutput;
        uint256 minVaultSharePrice;
        uint256 positionClosureLimit;
        bytes memory extraData;
        assembly {
            tendEnabled := tload(tendEnabledSlot)
            minOutput := tload(minOutputSlot)
            minVaultSharePrice := tload(minVaultSharePriceSlot)
            positionClosureLimit := tload(positionClosureLimitSlot)
            extraData := tload(extraDataSlot)
        }

        // Return the TendConfig.
        return (
            tendEnabled,
            IEverlongStrategy.TendConfig({
                minOutput: minOutput,
                minVaultSharePrice: minVaultSharePrice,
                positionClosureLimit: positionClosureLimit,
                extraData: extraData
            })
        );
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                        Position Closure Logic                         │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @dev Close only matured positions in the portfolio.
    /// @param _limit The maximum number of positions to close.
    ///               A value of zero indicates no limit.
    /// @return output Proceeds of closing the matured positions.
    function _closeMaturedPositions(
        uint256 _limit
    ) internal returns (uint256 output) {
        // A value of zero for `_limit` indicates no limit.
        if (_limit == 0) {
            _limit = type(uint256).max;
        }

        // Iterate through positions from most to least mature.
        // Exit if:
        // - There are no more positions.
        // - The current position is not mature.
        // - The limit on closed positions has been reached.
        IEverlongStrategy.EverlongPosition memory position;
        for (uint256 count; !_portfolio.isEmpty() && count < _limit; ++count) {
            // Retrieve the most mature position.
            position = _portfolio.head();

            // If the position is not mature, return the output received thus
            // far.
            if (!IHyperdrive(hyperdrive).isMature(position)) {
                return output;
            }

            // Close the position add the amount of assets received to the
            // cumulative output.
            output += IHyperdrive(hyperdrive).closeLong(
                asBase,
                position,
                0,
                ""
            );

            // Update portfolio accounting to reflect the closed position.
            _portfolio.handleClosePosition();
        }
    }

    /// @dev Close positions until the targeted amount of output is received.
    /// @param _targetOutput Target amount of proceeds to receive.
    /// @return output Total output received from closed positions.
    function _closePositions(
        uint256 _targetOutput
    ) internal returns (uint256 output) {
        // Round `_targetOutput` up to Hyperdrive's minimum transaction amount.
        _targetOutput = _targetOutput.max(_poolConfig.minimumTransactionAmount);

        // Since multiple position's worth of bonds may need to be closed,
        // iterate through each position starting with the most mature.
        //
        // For each position, use the expected output of closing the entire
        // position to estimate the amount of bonds to sell for a partial
        // closure.
        IEverlongStrategy.EverlongPosition memory position;
        uint256 totalPositionValue;
        while (!_portfolio.isEmpty() && output < _targetOutput) {
            // Retrieve the most mature position.
            position = _portfolio.head();

            // Calculate the value of the entire position, and use it to derive
            // the expected output for partial closures.
            totalPositionValue = IHyperdrive(hyperdrive).previewCloseLong(
                asBase,
                _poolConfig,
                position,
                ""
            );

            // Close only part of the position if there are sufficient bonds
            // to reach the target output without leaving a small amount left.
            // For this case, the remaining bonds must be worth at least
            // Hyperdrive's minimum transaction amount.
            if (
                totalPositionValue >
                (_targetOutput - output + _poolConfig.minimumTransactionAmount)
                    .mulUp(ONE + partialPositionClosureBuffer)
            ) {
                // Calculate the amount of bonds to close from the position.
                uint256 bondsNeeded = uint256(position.bondAmount).mulDivUp(
                    (_targetOutput - output).mulUp(
                        ONE + partialPositionClosureBuffer
                    ),
                    totalPositionValue
                );

                // Close part of the position and enforce the slippage guard.
                // Add the amount of assets received to the total output.
                output += IHyperdrive(hyperdrive).closeLong(
                    asBase,
                    IEverlongStrategy.EverlongPosition({
                        maturityTime: position.maturityTime,
                        bondAmount: bondsNeeded.toUint128()
                    }),
                    0,
                    ""
                );

                // Update portfolio accounting to include the partial closure.
                _portfolio.handleClosePosition(bondsNeeded);

                // No more closures are needed.
                return output;
            }
            // Close the entire position.
            else {
                // Close the entire position and increase the cumulative output.
                output += IHyperdrive(hyperdrive).closeLong(
                    asBase,
                    position,
                    0,
                    ""
                );

                // Update portfolio accounting to include the partial closure.
                _portfolio.handleClosePosition();
            }
        }

        // The target has been reached or no more positions remain.
        return output;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 Views                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Gets the max amount of `asset` that an address can deposit.
    /// @dev Only pre-approved addresses (vaults) are able to deposit.
    /// @param _depositor The address that is depositing into the strategy.
    /// @return The available amount the `_depositor` can deposit in terms of
    ///         `asset`.
    function availableDepositLimit(
        address _depositor
    ) public view override returns (uint256) {
        // Only pre-approved addresses are able to deposit.
        if (_depositors[_depositor] || _depositor == address(this)) {
            // Limit deposits to the maximum long that can be opened in hyperdrive.
            return IHyperdrive(hyperdrive).calculateMaxLong();
        }
        // Address has not been pre-approved, return 0.
        return 0;
    }

    /// @notice Weighted average maturity timestamp of the portfolio.
    /// @return Weighted average maturity timestamp of the portfolio.
    function avgMaturityTime() external view returns (uint128) {
        return _portfolio.avgMaturityTime;
    }

    /// @notice Calculates the present portfolio value using the total amount of
    ///         bonds and the weighted average maturity of all positions.
    /// @return value The present portfolio value.
    function calculatePortfolioValue() public view returns (uint256 value) {
        if (_portfolio.totalBonds != 0) {
            // NOTE: The maturity time is rounded to the next checkpoint to
            //       underestimate the portfolio value.
            value += IHyperdrive(hyperdrive).previewCloseLong(
                asBase,
                _poolConfig,
                IEverlongStrategy.EverlongPosition({
                    maturityTime: IHyperdrive(hyperdrive)
                        .getCheckpointIdUp(_portfolio.avgMaturityTime)
                        .toUint128(),
                    bondAmount: _portfolio.totalBonds
                }),
                ""
            );
        }
    }

    /// @notice Returns whether Everlong has sufficient idle liquidity to open
    ///         a new position.
    /// @return True if a new position can be opened, false otherwise.
    function canOpenPosition() public view returns (bool) {
        return
            asset.balanceOf(address(this)) >
            _poolConfig.minimumTransactionAmount;
    }

    /// @notice Returns whether the portfolio has matured positions.
    /// @return True if the portfolio has matured positions, false otherwise.
    function hasMaturedPositions() public view returns (bool) {
        return
            !_portfolio.isEmpty() &&
            IHyperdrive(hyperdrive).isMature(_portfolio.head());
    }

    /// @notice Retrieve the position at the specified location in the queue.
    /// @param _index Index in the queue to retrieve the position.
    /// @return The position at the specified location.
    function positionAt(
        uint256 _index
    ) external view returns (IEverlongStrategy.EverlongPosition memory) {
        return _portfolio.at(_index);
    }

    /// @notice Returns how many positions are currently in the queue.
    /// @return The queue's position count.
    function positionCount() external view returns (uint256) {
        return _portfolio.positionCount();
    }

    /// @notice Total quantity of bonds held in the portfolio.
    /// @return Total quantity of bonds held in the portfolio.
    function totalBonds() external view returns (uint256) {
        return _portfolio.totalBonds;
    }
}
