// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IEverlong } from "./interfaces/IEverlong.sol";
import { EVERLONG_KIND, EVERLONG_VERSION } from "./libraries/Constants.sol";
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

    // ───────────────────────── Immutables ──────────────────────

    // NOTE: Immutables accessed during transactions are left as internal
    //       to avoid the gas overhead of auto-generated getter functions.
    //       https://zokyo-auditing-tutorials.gitbook.io/zokyo-gas-savings/tutorials/gas-saving-technique-23-public-to-private-constants

    /// @dev Name of the Everlong token.
    string public _name;

    /// @dev Symbol of the Everlong token.
    string internal _symbol;

    /// @notice Address of the Hyperdrive instance wrapped by Everlong.
    address public immutable override hyperdrive;

    /// @dev Whether to use Hyperdrive's base token to purchase bonds.
    ///      If false, use the Hyperdrive's `vaultSharesToken`.
    bool public immutable asBase;

    /// @dev Address of the underlying asset to use with hyperdrive.
    address public immutable _asset;

    /// @dev Decimals to use with asset.
    uint8 internal immutable _decimals;

    /// @dev Kind of everlong.
    string public constant override kind = EVERLONG_KIND;

    /// @dev Version of everlong.
    string public constant override version = EVERLONG_VERSION;

    /// @notice Virtual shares are used to mitigate inflation attacks.
    bool public constant useVirtualShares = true;

    /// @notice Used to reduce the feasibility of an inflation attack.
    /// TODO: Determine the appropriate value for our case. Current value
    ///       was picked arbitrarily.
    uint8 public constant decimalsOffset = 3;

    // ─────────────────────────── State ────────────────────────

    /// @dev Address of the contract admin.
    address public admin;

    /// @dev Structure to store and account for everlong-controlled positions.
    Portfolio.State internal _portfolio;

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
    constructor(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        address _hyperdrive,
        bool _asBase
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
        // If everlong holds no bonds, return the balance.
        uint256 balance = ERC20(_asset).balanceOf(address(this));
        if (_portfolio.totalBonds == 0) {
            return balance;
        }

        // Estimate the value of everlong-controlled positions by calculating
        // the proceeds one would receive from closing a position with the portfolio's
        // total amount of bonds and weighted average maturity.
        // The weighted average maturity is rounded to the next checkpoint
        // timestamp to underestimate the value.
        return
            balance +
            IHyperdrive(hyperdrive).previewCloseLong(
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

    /// @dev Rebalance after a deposit if needed.
    function _afterDeposit(uint256, uint256) internal virtual override {
        if (canRebalance()) {
            rebalance();
        }
    }

    /// @dev Frees sufficient assets for a withdrawal by closing positions.
    /// @param assets Amount of assets owed to the withdrawer.
    function _beforeWithdraw(
        uint256 assets,
        uint256
    ) internal virtual override {
        // Close more positions until sufficient idle to process withdrawal.
        _closePositions(assets - ERC20(_asset).balanceOf(address(this)));
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Rebalancing                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Rebalance the everlong portfolio by closing mature positions
    ///         and using the proceeds to open new positions.
    function rebalance() public override {
        // Close matured positions.
        _closeMaturedPositions();

        // Spend idle on opening a new position. Leave an extra wei for the
        // approval to keep the slot warm.
        uint256 toSpend = ERC20(_asset).balanceOf(address(this));
        ERC20(_asset).forceApprove(address(hyperdrive), toSpend + 1);
        (uint256 maturityTime, uint256 bondAmount) = IHyperdrive(hyperdrive)
            .openLong(asBase, toSpend, "");

        // Account for the new position in the portfolio.
        _portfolio.handleOpenPosition(maturityTime, bondAmount);
    }

    // FIXME: Consider idle liquidity + maybe maxLong?
    //
    /// @notice Returns whether the portfolio needs rebalancing.
    /// @return True if the portfolio needs rebalancing, false otherwise.
    function canRebalance() public view returns (bool) {
        return true;
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
            output += IHyperdrive(hyperdrive).closeLong(asBase, position, "");
            _portfolio.handleClosePosition();
        }
        return output;
    }

    /// @dev Close positions until the targeted amount of output is received.
    /// @param _targetOutput Minimum amount of proceeds to receive.
    /// @return output Total output received from closed positions.
    function _closePositions(
        uint256 _targetOutput
    ) internal returns (uint256 output) {
        while (!_portfolio.isEmpty() && output < _targetOutput) {
            output += IHyperdrive(hyperdrive).closeLong(
                asBase,
                _portfolio.head(),
                ""
            );
            _portfolio.handleClosePosition();
        }
        return output;
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

    /// @notice The address of the underlying Hyperdrive Instance.
    /// @return The address of the underlying Hyperdrive Instance.
    function hyperdrive() external view override returns (address) {
        return address(_hyperdrive);
    }

    /// @notice Whether Everlong uses Hyperdrive's base token to transact.
    /// @return Whether Everlong uses Hyperdrive's base token to transact.
    function asBase() external view returns (bool) {
        return _asBase;
    }

    /// @notice Address of the token used to interact with the Hyperdrive instance.
    /// @return Address of the token used to interact with the Hyperdrive instance.
    function asset() public view override returns (address) {
        return address(_asset);
    }

    // FIXME: Consider idle liquidity + maybe maxLong?
    //
    /// @notice Returns whether the portfolio needs rebalancing.
    /// @return True if the portfolio needs rebalancing, false otherwise.
    function canRebalance() external view returns (bool) {
        return IHyperdrive(hyperdrive).isMature(_portfolio.head());
    }

    /// @notice Returns whether the portfolio has matured positions.
    /// @return True if the portfolio has matured positions, false otherwise.
    function hasMaturedPositions() external view returns (bool) {
        return IHyperdrive(hyperdrive).isMature(_portfolio.head());
    }

    /// @notice Retrieve the position at the specified location in the queue..
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
