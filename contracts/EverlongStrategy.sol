// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { BaseStrategy, ERC20 } from "tokenized-strategy/BaseStrategy.sol";
import { IEverlongStrategy } from "./interfaces/IEverlongStrategy.sol";
import { EVERLONG_STRATEGY_KIND, EVERLONG_VERSION, ONE } from "./libraries/Constants.sol";
import { HyperdriveExecutionLibrary } from "./libraries/HyperdriveExecution.sol";
import { Portfolio } from "./libraries/Portfolio.sol";

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
    using Portfolio for Portfolio.State;
    using SafeCast for *;
    using SafeERC20 for ERC20;

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

    /// @dev Configuration for how `_tend(..)` is performed.
    IEverlongStrategy.TendConfig internal _tendConfig;

    /// @dev Structure to store and account for everlong-controlled positions.
    Portfolio.State internal _portfolio;

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
    /// @dev Any difference between `_amount` and what is actually freed will be
    ///      counted as a loss and passed on to the withdrawer.
    /// @param _amount The amount of 'asset' to be freed.
    function _freeFunds(uint256 _amount) internal override {
        // Close all matured positions (if any).
        uint256 output = _closeMaturedPositions(0);

        // Close immature positions if additional funds need to be freed.
        if (_amount > output) {
            _closePositions(_amount - output);
        }
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
            _tend(ERC20(asset).balanceOf(address(this)));
        }

        // Recalculate the value of assets the strategy controls.
        _totalAssets = calculateTotalAssets();
    }

    /// @dev Can be called inbetween reports to rebalance the portfolio.
    /// @param _totalIdle The current amount of idle funds that are available to
    ///         deploy.
    function _tend(uint256 _totalIdle) internal override {
        // Close matured positions.
        _totalIdle += _closeMaturedPositions(_tendConfig.positionClosureLimit);

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
                    _tendConfig.minOutput,
                    _tendConfig.minVaultSharePrice,
                    _tendConfig.extraData
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
        IEverlongStrategy.Position memory position;
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
        IEverlongStrategy.Position memory position;
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
                    IEverlongStrategy.Position({
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
    // │                                Setters                                │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Sets the minimum number of bonds to receive when opening a long.
    /// @param _minOutput Minimum number of bonds to receive when opening a
    ///        long.
    function setMinOutput(uint256 _minOutput) external onlyKeepers {
        _tendConfig.minOutput = _minOutput;
    }

    /// @notice Sets the minimum vault share price when opening a long.
    /// @param _minVaultSharePrice Minimum vault share price when opening a
    ///        long.
    function setMinVaultSharePrice(
        uint256 _minVaultSharePrice
    ) external onlyKeepers {
        _tendConfig.minVaultSharePrice = _minVaultSharePrice;
    }

    /// @notice Sets the max amount of mature positions to close at a time.
    /// @param _positionClosureLimit Max amount of mature positions to close at
    ///        a time.
    function setPositionClosureLimit(
        uint256 _positionClosureLimit
    ) external onlyKeepers {
        _tendConfig.positionClosureLimit = _positionClosureLimit;
    }

    /// @notice Sets the extra data to pass to hyperdrive when opening/closing
    ///         longs.
    /// @param _extraData Extra data to pass to hyperdrive when opening/closing
    ///         longs.
    function setExtraData(bytes memory _extraData) external onlyKeepers {
        _tendConfig.extraData = _extraData;
    }

    // ╭───────────────────────────────────────────────────────────────────────╮
    // │                                 Views                                 │
    // ╰───────────────────────────────────────────────────────────────────────╯

    /// @notice Gets the max amount of `asset` that an address can deposit.
    /// @param . The address that is depositing into the strategy.
    /// @return The available amount the `_owner` can deposit in terms of
    ///         `asset`.
    function availableDepositLimit(
        address
    ) public view override returns (uint256) {
        // Limit deposits to the maximum long that can be opened in hyperdrive.
        return IHyperdrive(hyperdrive).calculateMaxLong();
    }

    /// @notice Weighted average maturity timestamp of the portfolio.
    /// @return Weighted average maturity timestamp of the portfolio.
    function avgMaturityTime() external view returns (uint128) {
        return _portfolio.avgMaturityTime;
    }

    /// @notice Calculates the present portfolio value using the total amount of
    ///      bonds and the weighted average maturity of all positions.
    /// @return value The present portfolio value.
    function calculateTotalAssets() public view returns (uint256 value) {
        value = ERC20(asset).balanceOf(address(this));
        if (_portfolio.totalBonds != 0) {
            // NOTE: The maturity time is rounded to the next checkpoint to
            //       underestimate the portfolio value.
            value += IHyperdrive(hyperdrive).previewCloseLong(
                asBase,
                _poolConfig,
                IEverlongStrategy.Position({
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

    /// @notice Gets the minimum number of bonds to receive when opening a long.
    /// @return Minimum number of bonds to receive when opening a long.
    function getMinOutput() external view returns (uint256) {
        return _tendConfig.minOutput;
    }

    /// @notice Gets the minimum vault share price when opening a long.
    /// @return Minimum vault share price when opening a long.
    function getMinVaultSharePrice() external view returns (uint256) {
        return _tendConfig.minVaultSharePrice;
    }

    /// @notice Gets the max amount of mature positions to close at a time.
    /// @return Max amount of mature positions to close at a time.
    function getPositionClosureLimit() external view returns (uint256) {
        return _tendConfig.positionClosureLimit;
    }

    /// @notice Gets the extra data to pass to hyperdrive when opening/closing
    ///         longs.
    /// @return Extra data to pass to hyperdrive when opening/closing longs.
    function getExtraData() external view returns (bytes memory) {
        return _tendConfig.extraData;
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
    ) external view returns (IEverlongStrategy.Position memory) {
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
