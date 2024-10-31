// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { IEverlong } from "./interfaces/IEverlong.sol";
import { EVERLONG_KIND, EVERLONG_VERSION, ONE } from "./libraries/Constants.sol";
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
/// @title Everlong
/// @notice A money market powered by Hyperdrive.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract Everlong is IEverlong {
    using FixedPointMath for uint256;
    using HyperdriveExecutionLibrary for IHyperdrive;
    using Portfolio for Portfolio.State;
    using SafeCast for *;
    using SafeERC20 for ERC20;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Storage                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    // ───────────────────────── Constants ───────────────────────

    /// @notice Kind of everlong.
    string public constant override kind = EVERLONG_KIND;

    /// @notice Version of everlong.
    string public constant override version = EVERLONG_VERSION;

    /// @notice Virtual shares are used to mitigate inflation attacks.
    bool public constant useVirtualShares = true;

    /// @notice Used to reduce the feasibility of an inflation attack.
    /// TODO: Determine the appropriate value for our case. Current value
    ///       was picked arbitrarily.
    uint8 public constant decimalsOffset = 3;

    /// @notice Maximum slippage allowed when closing longs with Hyperdrive.
    /// @dev Represented as a percentage with 1e18 signifying 100%.
    uint256 public constant maxCloseLongSlippage = 0.001e18;

    /// @notice Amount of additional bonds to close during a partial position
    ///         closure to avoid rounding errors. Represented as a percentage
    ///         of the positions total  amount of bonds where 0.1e18 represents
    ///         a 10% buffer.
    uint256 public constant partialPositionClosureBuffer = 0.001e18;

    // ───────────────────────── Immutables ──────────────────────

    /// @dev Name of the Everlong token.
    string internal _name;

    /// @dev Symbol of the Everlong token.
    string internal _symbol;

    /// @notice Address of the Hyperdrive instance wrapped by Everlong.
    address public immutable override hyperdrive;

    /// @notice Whether to use Hyperdrive's base token to purchase bonds.
    ///      If false, use the Hyperdrive's `vaultSharesToken`.
    bool public immutable asBase;

    /// @dev Address of the underlying asset to use with hyperdrive.
    address internal immutable _asset;

    /// @dev Decimals to use with asset.
    uint8 internal immutable _decimals;

    /// @notice Target percentage of assets to leave uninvested.
    uint256 public immutable targetIdleLiquidityPercentage;

    /// @notice Maximum percentage of assets to leave uninvested.
    uint256 public immutable maxIdleLiquidityPercentage;

    // ─────────────────────────── State ────────────────────────

    /// @notice Address of the contract admin.
    address public admin;

    /// @dev Structure to store and account for everlong-controlled positions.
    Portfolio.State internal _portfolio;

    /// @notice Estimation of the total amount of assets controlled by Everlong.
    uint256 internal _totalAssets;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Modifiers                                               │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Ensures that the contract is being called by admin.
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert IEverlong.Unauthorized();
        }
        _;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Constructor                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Initial configuration paramters for EverlongERC4626.
    /// @param __name Name of the ERC20 token managed by Everlong.
    /// @param __symbol Symbol of the ERC20 token managed by Everlong.
    /// @param __decimals Decimals of the Everlong token and Hyperdrive token.
    /// @param _hyperdrive Address of the Hyperdrive instance.
    /// @param _asBase Whether to use the base or shares token from Hyperdrive.
    /// @param _targetIdleLiquidityPercentage Target percentage of funds to
    ///        keep idle.
    /// @param _maxIdleLiquidityPercentage Max percentage of funds to keep
    ///        idle.
    constructor(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        address _hyperdrive,
        bool _asBase,
        uint256 _targetIdleLiquidityPercentage,
        uint256 _maxIdleLiquidityPercentage
    ) {
        // Store constructor parameters.
        _name = __name;
        _symbol = __symbol;
        _decimals = __decimals;
        hyperdrive = _hyperdrive;
        asBase = _asBase;
        _asset = _asBase
            ? IHyperdrive(_hyperdrive).baseToken()
            : IHyperdrive(_hyperdrive).vaultSharesToken();

        // Ensure target <= 1e18 and max <= 1e18.
        if (
            _targetIdleLiquidityPercentage > ONE ||
            _maxIdleLiquidityPercentage > ONE
        ) {
            revert PercentageTooLarge();
        }

        // Ensure target < max.
        if (_targetIdleLiquidityPercentage > _maxIdleLiquidityPercentage) {
            revert TargetIdleGreaterThanMax();
        }

        // Store idle and max.
        targetIdleLiquidityPercentage = _targetIdleLiquidityPercentage;
        maxIdleLiquidityPercentage = _maxIdleLiquidityPercentage;

        // Set the admin to the contract deployer.
        admin = msg.sender;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Admin                                                   │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Allows admin to transfer the admin role.
    /// @param _admin The new admin address.
    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
        emit AdminUpdated(_admin);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ ERC4626                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Calculate the total amount of assets controlled by everlong.
    /// @notice To do this efficiently, the weighted average maturity is used.
    /// @dev Underestimates the actual value by overestimating the average
    ///      maturity of the portfolio.
    /// @return Total amount of assets controlled by Everlong.
    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    /// @notice Returns an approximate lower bound on the amount of assets
    ///         received from redeeming the specified amount of shares.
    /// @param _shares Amount of shares to redeem.
    /// @return assets Amount of assets that will be received.
    function previewRedeem(
        uint256 _shares
    ) public view override returns (uint256 assets) {
        // Convert the share amount to assets.
        assets = convertToAssets(_shares);

        // TODO: Hold the vault share price constant.
        //
        // Apply losses incurred by the portfolio.
        uint256 losses = _calculatePortfolioLosses().mulDivUp(
            assets,
            _totalAssets
        );

        // If the losses from closing immature positions exceeds the assets
        // owed to the redeemer, set the assets owed to zero.
        if (losses > assets) {
            // NOTE: We return zero since `previewRedeem` must not revert.
            assets = 0;
        }
        // Decrement the assets owed to the redeemer by the amount of losses
        // incurred from closing immature positions.
        else {
            unchecked {
                assets -= losses;
            }
        }
    }

    // TODO: Do not rebalance on deposit. This change will require updating
    //       the test suite as well to perform rebalances when time is advanced.
    //
    /// @dev Attempt rebalancing after a deposit if idle is above max.
    function _afterDeposit(uint256 _assets, uint256) internal virtual override {
        // If there is excess liquidity beyond the max, rebalance.
        if (ERC20(_asset).balanceOf(address(this)) > maxIdleLiquidity()) {
            rebalance();
        } else {
            _totalAssets += _assets;
        }
    }

    /// @dev Frees sufficient assets for a withdrawal by closing positions.
    /// @param _assets Amount of assets owed to the withdrawer.
    function _beforeWithdraw(
        uint256 _assets,
        uint256
    ) internal virtual override {
        // If no assets are to be received, revert.
        if (_assets == 0) {
            revert IEverlong.RedemptionZeroOutput();
        }

        // TODO: Determine if we want to close enough positions to leave the
        //       correct amount of idle liquidity after the withdrawal is
        //       processed. Doing so at this time would likely result in less
        //       overall gas usage.
        //
        // If we do not have enough balance to service the withdrawal after
        // closing any matured positions, close more positions.
        uint256 balance = ERC20(_asset).balanceOf(address(this)) +
            _closeMaturedPositions();
        if (_assets > balance) {
            _closePositions(_assets - balance);
        }

        // Recalculate the assets under Everlong control less the amount being
        // withdrawn.
        _totalAssets = _calculateTotalAssets() - _assets;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Rebalancing                                             │
    // ╰─────────────────────────────────────────────────────────╯

    // TODO: Handle case where rebalancing would exceed gas limit
    // TODO: Handle when Hyperdrive has insufficient liquidity.
    //
    /// @notice Rebalance the everlong portfolio by closing mature positions
    ///         and using the proceeds over target idle to open new positions.
    function rebalance() public override {
        // Early return if no rebalancing is needed.
        if (!canRebalance()) {
            return;
        }

        // Calculate the new portfolio value and save it.
        _totalAssets = _calculateTotalAssets();

        // Close matured positions.
        _closeMaturedPositions();

        // Amount to spend is the current balance less the target idle.
        uint256 toSpend = ERC20(_asset).balanceOf(address(this)) -
            targetIdleLiquidity();

        // Open a new position. Leave an extra wei for the approval to keep
        // the slot warm.
        ERC20(_asset).forceApprove(address(hyperdrive), toSpend + 1);
        (uint256 maturityTime, uint256 bondAmount) = IHyperdrive(hyperdrive)
            .openLong(asBase, toSpend, "");

        // Account for the new position in the portfolio.
        _portfolio.handleOpenPosition(maturityTime, bondAmount);

        emit Rebalanced();
    }

    // TODO: Use cached poolconfig.
    //
    /// @notice Returns true if the portfolio can be rebalanced.
    /// @notice The portfolio can be rebalanced if:
    ///         - Any positions are matured.
    ///         - The current idle liquidity is above the target.
    /// @return True if the portfolio can be rebalanced, false otherwise.
    function canRebalance() public view returns (bool) {
        uint256 balance = ERC20(_asset).balanceOf(address(this));
        uint256 target = targetIdleLiquidity();
        return (hasMaturedPositions() ||
            (balance > target &&
                balance - target >
                IHyperdrive(hyperdrive)
                    .getPoolConfig()
                    .minimumTransactionAmount));
    }

    /// @notice Returns the target amount of funds to keep idle in Everlong.
    /// @dev If the target amount is lower than Hyperdrive's minimum,
    ///      then Hyperdrive's minimum becomes the target.
    /// @return Target amount of idle assets.
    function targetIdleLiquidity() public view returns (uint256) {
        return _calculateTargetIdleLiquidity(_totalAssets);
    }

    // TODO: Use cached poolconfig
    //
    /// @dev Calculates the target amount of idle funds given the input amount
    ///      of assets.
    /// @param _assets Total assets to calculate the target from.
    /// @return Target amount of idle assets.
    function _calculateTargetIdleLiquidity(
        uint256 _assets
    ) internal view returns (uint256) {
        return
            targetIdleLiquidityPercentage.mulDown(_assets).max(
                IHyperdrive(hyperdrive).getPoolConfig().minimumTransactionAmount
            );
    }

    // TODO: Use cached poolconfig
    //
    /// @notice Returns the max amount of funds to keep idle in Everlong.
    /// @dev If the max amount is lower than Hyperdrive's minimum,
    ///      then Hyperdrive's minimum becomes the max.
    /// @return assets Maximum amount of idle assets.
    function maxIdleLiquidity() public view returns (uint256 assets) {
        assets = maxIdleLiquidityPercentage.mulDown(_totalAssets).max(
            IHyperdrive(hyperdrive).getPoolConfig().minimumTransactionAmount
        );
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Hyperdrive                                              │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Close only matured positions in the portfolio.
    /// @return output Proceeds of closing the matured positions.
    function _closeMaturedPositions() internal returns (uint256 output) {
        IEverlong.Position memory position;
        while (!_portfolio.isEmpty()) {
            position = _portfolio.head();
            if (!IHyperdrive(hyperdrive).isMature(position)) {
                return output;
            }
            output += IHyperdrive(hyperdrive).closeLong(
                asBase,
                position,
                0,
                ""
            );
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
        _targetOutput = _targetOutput.max(
            IHyperdrive(hyperdrive).getPoolConfig().minimumTransactionAmount
        );

        // Since multiple position's worth of bonds may need to be closed,
        // iterate through each position starting with the most mature.
        //
        // For each position, use the expected output of closing the entire
        // position to estimate the amount of bonds to sell for a partial closure.
        IEverlong.Position memory position;
        uint256 totalPositionValue;
        while (!_portfolio.isEmpty() && output < _targetOutput) {
            // Retrieve the most mature position.
            position = _portfolio.head();

            // Calculate the value of the entire position, and use it to derive
            // the expected output for partial closures.
            totalPositionValue = IHyperdrive(hyperdrive).previewCloseLong(
                asBase,
                position,
                ""
            );

            // Close only part of the position if there are sufficient bonds
            // to reach the target output without leaving a small amount left.
            // For this case, the remaining bonds must be worth at least
            // Hyperdrive's minimum transaction amount.
            if (
                totalPositionValue >
                (_targetOutput -
                    output +
                    IHyperdrive(hyperdrive)
                        .getPoolConfig()
                        .minimumTransactionAmount).mulUp(
                        1e18 + partialPositionClosureBuffer
                    )
            ) {
                // Calculate the amount of bonds to close from the position.
                uint256 bondsNeeded = uint256(position.bondAmount).mulDivUp(
                    (_targetOutput - output).mulUp(
                        1e18 + partialPositionClosureBuffer
                    ),
                    totalPositionValue
                );

                // Close part of the position and enforce the slippage guard.
                // Add the amount of assets received to the total output.
                output += IHyperdrive(hyperdrive).closeLong(
                    asBase,
                    IEverlong.Position({
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

    /// @dev Calculates the present portfolio value using the total amount of
    ///      bonds and the weighted average maturity of all positions.
    /// @return value The present portfolio value.
    function _calculateTotalAssets() internal view returns (uint256 value) {
        value = ERC20(_asset).balanceOf(address(this));
        if (_portfolio.totalBonds != 0) {
            // NOTE: The maturity time is rounded to the next checkpoint to
            // underestimate the portfolio value.
            value += IHyperdrive(hyperdrive).previewCloseLong(
                asBase,
                IEverlong.Position({
                    maturityTime: IHyperdrive(hyperdrive)
                        .getCheckpointIdUp(_portfolio.avgMaturityTime)
                        .toUint128(),
                    bondAmount: _portfolio.totalBonds
                }),
                ""
            );
        }
    }

    /// @dev Calculates the amount of losses the portfolio has incurred since
    ///      `_totalAssets` was last calculated. If no losses have been incurred
    ///      return 0.
    /// @return Amount of losses incurred by the portfolio (if any).
    function _calculatePortfolioLosses() internal view returns (uint256) {
        uint256 newTotalAssets = _calculateTotalAssets();
        if (_totalAssets > newTotalAssets) {
            return _totalAssets - newTotalAssets;
        }
        return 0;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Name of the Everlong token.
    /// @return Name of the Everlong token.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Symbol of the Everlong token.
    /// @return Symbol of the Everlong token.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @dev The underlying asset decimals.
    /// @return The underlying asset decimals.
    function _underlyingDecimals()
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _decimals;
    }

    /// @dev The decimal offset used for virtual shares.
    /// @return The decimal offset used for virtual shares.
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return decimalsOffset;
    }

    /// @notice Address of the token used to interact with the Hyperdrive instance.
    /// @return Address of the token used to interact with the Hyperdrive instance.
    function asset() public view override returns (address) {
        return address(_asset);
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
    ) external view returns (IEverlong.Position memory) {
        return _portfolio.at(_index);
    }

    /// @notice Returns how many positions are currently in the queue.
    /// @return The queue's position count.
    function positionCount() external view returns (uint256) {
        return _portfolio.positionCount();
    }

    /// @notice Calculates the estimated value of the position at _index.
    /// @param _index Location of the position to value.
    /// @return Estimated proceeds of closing the position.
    function positionValue(uint256 _index) external view returns (uint256) {
        return
            IHyperdrive(hyperdrive).previewCloseLong(
                asBase,
                _portfolio.at(_index),
                ""
            );
    }

    /// @notice Weighted average maturity timestamp of the portfolio.
    /// @return Weighted average maturity timestamp of the portfolio.
    function avgMaturityTime() external view returns (uint128) {
        return _portfolio.avgMaturityTime;
    }

    /// @notice Total quantity of bonds held in the portfolio.
    /// @return Total quantity of bonds held in the portfolio.
    function totalBonds() external view returns (uint128) {
        return _portfolio.totalBonds;
    }
}
