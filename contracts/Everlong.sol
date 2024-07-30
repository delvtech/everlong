// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { Admin } from "./Admin.sol";
import { PositionManager } from "./PositionManager.sol";
import { IRebalancing } from "./interfaces/IRebalancing.sol";

import { DoubleEndedQueue } from "openzeppelin/utils/structs/DoubleEndedQueue.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { ERC4626 } from "solady/tokens/ERC4626.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";

///           ,---..-.   .-.,---.  ,---.   ,-.    .---.  .-. .-.  ,--,
///           | .-' \ \ / / | .-'  | .-.\  | |   / .-. ) |  \| |.' .'
///           | `-.  \ V /  | `-.  | `-'/  | |   | | |(_)|   | ||  |  __
///           | .-'   ) /   | .-'  |   (   | |   | | | | | |\  |\  \ ( _)
///           |  `--.(_)    |  `--.| |\ \  | `--.\ `-' / | | |)| \  `-) )
///           /( __.'       /( __.'|_| \)\ |( __.')---'  /(  (_) )\____/
///          (__)          (__)        (__)(_)   (_)    (__)    (__)
///
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
///
/// @author DELV
/// @title Everlong
/// @notice A money market powered by Hyperdrive.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract Everlong is Admin, ERC4626, PositionManager, IRebalancing {
    /// @notice Virtual shares are used to mitigate inflation attacks.
    bool public constant useVirtualShares = true;

    /// @notice Used to reduce the feasibility of an inflation attack.
    /// TODO: Determine the appropriate value for our case. Current value
    ///       was picked arbitrarily.
    uint8 public constant decimalsOffset = 3;

    /// @dev Address of the Hyperdrive instance wrapped by Everlong.
    address internal immutable _hyperdrive;

    /// @dev Address of the token to use for Hyperdrive bond purchase/close.
    address internal immutable _asset;

    /// @dev Whether to use the Hyperdrive's base token to purchase bonds.
    //          If false, use the Hyperdrive's `vaultSharesToken`.
    bool internal immutable _asBase;

    /// @dev Decimals used by the `_asset`.
    uint8 internal immutable _decimals;

    /// @dev Target idle liquidity represented as a fraction of 1e18.
    uint256 internal _targetIdleLiquidity;

    /// @dev Name of the Everlong token.
    string internal _name;

    /// @dev Symbol of the Everlong token.
    string internal _symbol;

    /// @dev Last checkpoint time the portfolio was rebalanced.
    uint256 internal _lastRebalancedTimestamp;

    /// @notice Initial configuration paramters for Everlong.
    /// @param hyperdrive_ Address of the Hyperdrive instance wrapped by Everlong.
    /// @param name_ Name of the ERC20 token managed by Everlong.
    /// @param symbol_ Symbol of the ERC20 token managed by Everlong.
    /// @param asBase_ Whether to use the Hyperdrive's base token for bond purchases.
    constructor(
        string memory name_,
        string memory symbol_,
        address hyperdrive_,
        bool asBase_,
        uint256 targetIdleLiquidity_
    ) Admin() {
        // Store constructor parameters.
        _name = name_;
        _symbol = symbol_;
        _hyperdrive = hyperdrive_;
        _asBase = asBase_;
        _asset = _asBase
            ? IHyperdrive(_hyperdrive).baseToken()
            : IHyperdrive(_hyperdrive).vaultSharesToken();
        _targetIdleLiquidity = targetIdleLiquidity_;

        // Attempt to retrieve the decimals from the {_asset} contract.
        // If it does not implement `decimals() (uint256)`, use the default.
        (bool success, uint8 result) = _tryGetAssetDecimals(asset());
        _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;

        // Give max approval for `_asset` to the hyperdrive contract.
        IERC20(_asset).approve(hyperdrive_, type(uint256).max);
    }

    function hyperdrive() public view returns (address) {
        return _hyperdrive;
    }

    /// @notice Address of the underlying Hyperdrive instance.
    /// @dev MUST be an ERC20 token contract.
    /// @return Hyperdrive address.
    function asset() public view virtual override returns (address) {
        return _asset;
    }

    /// @notice Returns the name of the Everlong token.
    /// @return Everlong token name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the Everlong token.
    /// @return Everlong token symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the kind of the Everlong instance.
    /// @return Everlong contract kind.
    function kind() public view virtual returns (string memory) {
        return "Everlong";
    }

    /// @notice Returns the version of the Everlong instance.
    /// @return Everlong contract version.
    function version() public view virtual returns (string memory) {
        return "v0.0.1";
    }

    /// @inheritdoc IRebalancing
    function canRebalance() public view returns (bool) {
        return
            hasMaturedPositions() ||
            IERC20(_asset).balanceOf(address(this)) >=
            IHyperdrive(_hyperdrive).getPoolConfig().minimumTransactionAmount;
    }

    /// @inheritdoc IRebalancing
    function rebalance() external override {
        // If there is no need for rebalancing, return.
        if (!canRebalance()) return;

        // First close all mature positions, then open new positions.
        // Closing is done before opening so that the proceeds from closing
        // can be used in the purchase of new positions.
        _closePositions();
        _openPositions();

        // Emit the `Rebalanced()` event.
        emit Rebalanced();
    }

    /// @dev Returns whether virtual shares will be used to mitigate the inflation attack.
    /// @dev See: https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3706
    /// @dev MUST NOT revert.
    function _useVirtualShares() internal view virtual override returns (bool) {
        return useVirtualShares;
    }

    /// @dev Returns the number of decimals of the underlying asset.
    /// @dev MUST NOT revert.
    function _underlyingDecimals()
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _decimals;
    }

    /// @dev A non-zero value used to make the inflation attack even more unfeasible.
    /// @dev MUST NOT revert.
    function _decimalsOffset() internal view virtual override returns (uint8) {
        return decimalsOffset;
    }

    // TODO: Might not need this but including for convenience.
    function _beforeWithdraw(uint256, uint256) internal override {
        // revert("TODO");
    }

    // TODO: Might not need this but including for convenience.
    function _afterDeposit(uint256, uint256) internal override {
        // revert("TODO");
    }

    // TODO: Include consideration for idle liquidity.
    /// @dev Open the maximum amount of positions possible
    ///      with the contract's current balance.
    function _openPositions() internal {
        // Obtain the current balance of the contract.
        // If the balance is less than hyperdrive's min tx amount, return.
        // If the balance is greater, use it all to open longs.
        uint256 _currentBalance = IERC20(_asset).balanceOf(address(this));
        uint256 _minTxAmount = IHyperdrive(_hyperdrive)
            .getPoolConfig()
            .minimumTransactionAmount;
        if (_currentBalance <= _minTxAmount) return;
        // TODO: Worry about slippage.
        (uint256 _maturityTime, uint256 _bondAmount) = IHyperdrive(_hyperdrive)
            .openLong(
                _currentBalance,
                0,
                0,
                IHyperdrive.Options(address(this), _asBase, "")
            );

        // Update accounting for the newly opened bond positions.
        _recordLongsOpened(uint128(_maturityTime), uint128(_bondAmount));
    }

    /// @dev Close all matured positions.
    function _closePositions() internal {
        // Loop through mature positions and close them all.
        Position memory _position;
        // TODO: Enable closing of mature positions incrementally to avoid
        //       the case where the # of mature positions exceeds the max
        //       gas per block.
        while (hasMaturedPositions()) {
            // Retrieve the oldest matured position and close it.
            _position = getPosition(0);
            IHyperdrive(_hyperdrive).closeLong(
                _position.maturityTime,
                _position.bondAmount,
                0,
                IHyperdrive.Options(address(this), _asBase, "")
            );

            // Update accounting for the closed long position.
            _recordLongsClosed(uint128(_position.bondAmount));
        }
    }
}
