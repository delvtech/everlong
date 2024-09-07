// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
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

    // ╭─────────────────────────────────────────────────────────╮
    // │ Storage                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    // ───────────────────────── Immutables ──────────────────────

    // @FIXME: Comments

    // NOTE: Immutables accessed during transactions are left as internal
    //       to avoid the gas overhead of auto-generated getter functions.
    //       https://zokyo-auditing-tutorials.gitbook.io/zokyo-gas-savings/tutorials/gas-saving-technique-23-public-to-private-constants

    /// @dev Name of the Everlong token.
    string internal _name;

    /// @dev Symbol of the Everlong token.
    string internal _symbol;

    /// @notice Address of the Hyperdrive instance wrapped by Everlong.
    IHyperdrive internal immutable _hyperdrive;

    /// @dev Whether to use Hyperdrive's base token to purchase bonds.
    ///      If false, use the Hyperdrive's `vaultSharesToken`.
    bool internal immutable _asBase;

    IERC20 internal immutable _asset;

    uint8 internal immutable _decimals;

    string public constant override kind = EVERLONG_KIND;

    string public constant override version = EVERLONG_VERSION;

    /// @notice Virtual shares are used to mitigate inflation attacks.
    bool public constant useVirtualShares = true;

    /// @notice Used to reduce the feasibility of an inflation attack.
    /// TODO: Determine the appropriate value for our case. Current value
    ///       was picked arbitrarily.
    uint8 public constant decimalsOffset = 3;

    // ────────────────────────── Internal ───────────────────────

    // @FIXME: Comments

    Portfolio.State internal _portfolio;

    /// @dev Address of the contract admin.
    address internal _admin;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Modifiers                                               │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Ensures that the contract is being called by admin.
    modifier onlyAdmin() {
        if (msg.sender != _admin) {
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
    /// @param __hyperdrive Address of the Hyperdrive instance.
    /// @param __asBase Whether to use the base or shares token from Hyperdrive.
    constructor(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        address __hyperdrive,
        bool __asBase
    ) {
        // Store constructor parameters.
        _name = __name;
        _symbol = __symbol;
        _decimals = __decimals;
        _hyperdrive = IHyperdrive(__hyperdrive);
        _asBase = __asBase;
        _asset = IERC20(
            __asBase
                ? IHyperdrive(__hyperdrive).baseToken()
                : IHyperdrive(__hyperdrive).vaultSharesToken()
        );
        // Set the admin to the contract deployer.
        _admin = msg.sender;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Admin                                                   │
    // ╰─────────────────────────────────────────────────────────╯

    function setAdmin(address admin_) external onlyAdmin {
        _admin = admin_;
        emit AdminUpdated(admin_);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ ERC4626                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    function totalAssets() public view override returns (uint256) {
        uint256 balance = _asset.balanceOf(address(this));
        if (_portfolio.totalBonds == 0) {
            return balance;
        }
        return
            balance +
            _hyperdrive.previewCloseLong(
                _asBase,
                IEverlong.Position({
                    maturityTime: _portfolio.avgMaturityTime,
                    bondAmount: _portfolio.totalBonds
                })
            );
    }

    function previewRedeem(
        uint256 shares
    ) public view override returns (uint256 assets) {
        assets = convertToAssets(shares);
        uint256 balance = _asset.balanceOf(address(this));
        if (assets <= balance) {
            return assets;
        }
        // Close positions until balance >= assets.
        IEverlong.Position memory position;
        uint256 i;
        uint256 output;
        uint256 count = _portfolio.positionCount();
        while (balance < assets && i < count) {
            position = _portfolio.at(i);
            output = _hyperdrive.previewCloseLong(_asBase, position);
            balance += output;
            i++;
        }
    }

    function maxDeposit(
        address _depositor
    ) public view override returns (uint256) {
        // HACK: Silence the voices.
        _depositor = _depositor;
        return HyperdriveUtils.calculateMaxLong(_hyperdrive);
    }

    function maxMint(address _minter) public view override returns (uint256) {
        // Silence the voices.
        _minter = _minter;
        return convertToShares(maxDeposit(_minter));
    }

    function _beforeWithdraw(
        uint256 _assets,
        uint256
    ) internal virtual override {
        // Close matured positions.
        _closeMaturedLongs();

        // Close more positions until sufficient idle to process withdrawal.
        _closeLongs(_assets - _asset.balanceOf(address(this)));
        if (_assets > _asset.balanceOf(address(this))) {
            console.log("Want: %s", _assets);
            console.log("Have: %s", _asset.balanceOf(address(this)));
            revert("Couldnt pay out withdrawal");
        }
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Rebalancing                                             │
    // ╰─────────────────────────────────────────────────────────╯

    function rebalance() public override {
        // Close matured positions.
        _closeMaturedLongs();

        // Spend idle.
        uint256 toSpend = _asset.balanceOf(address(this));
        IERC20(_asset).approve(address(_hyperdrive), toSpend);
        (uint256 maturityTime, uint256 bondAmount) = _hyperdrive.openLong(
            _asBase,
            toSpend
        );
        _portfolio.handleOpenPosition(maturityTime, bondAmount);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Hyperdrive                                              │
    // ╰─────────────────────────────────────────────────────────╯

    function _closeMaturedLongs() internal returns (uint256 output) {
        IEverlong.Position memory position;
        while (!_portfolio.isEmpty()) {
            position = _portfolio.head();
            if (!_hyperdrive.isMature(position)) {
                return output;
            }
            output += _hyperdrive.closeLong(_asBase, position);
            _portfolio.handleClosePosition();
        }
        return output;
    }

    function _estimateCloseMaturedLongs()
        internal
        view
        returns (uint256 output)
    {
        IEverlong.Position memory position;
        uint256 i;
        uint256 count = _portfolio.positionCount();
        while (i < count) {
            position = _portfolio.at(i);
            if (!_hyperdrive.isMature(position)) {
                return output;
            }
            output += _hyperdrive.previewCloseLong(_asBase, position);
            i++;
        }
    }

    function _closeLongs(
        uint256 _targetOutput
    ) internal returns (uint256 output) {
        while (!_portfolio.isEmpty() && output < _targetOutput) {
            output += _hyperdrive.closeLong(_asBase, _portfolio.head());
            _portfolio.handleClosePosition();
        }
        return output;
    }

    function _estimateCloseLongs(
        uint256 _targetOutput
    ) internal view returns (uint256 output) {
        uint256 i;
        uint256 count = _portfolio.positionCount();
        while (i < count && output < _targetOutput) {
            output += _hyperdrive.previewCloseLong(_asBase, _portfolio.at(i));
            i++;
        }
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Name of the Everlong token.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Symbol of the Everlong token.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice Gets the address of the underlying Hyperdrive Instance.
    function hyperdrive() external view override returns (address) {
        return address(_hyperdrive);
    }

    /// @notice Gets whether Everlong uses Hyperdrive's base token to
    ///         transact.
    function asBase() external view returns (bool) {
        return _asBase;
    }

    /// @notice Gets the address of the token used to interact with the
    ///         Hyperdrive instance.
    function asset() public view override returns (address) {
        return address(_asset);
    }

    /// @notice Gets the amount of decimals for `asset`.
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Gets the admin address for Everlong.
    function admin() external view returns (address) {
        return _admin;
    }

    // FIXME: Consider idle liquidity
    function canRebalance() external view returns (bool) {
        return _hyperdrive.isMature(_portfolio.head());
    }

    function hasMaturedPositions() external view returns (bool) {
        return _hyperdrive.isMature(_portfolio.head());
    }

    function positionAt(
        uint256 _index
    ) external view returns (IEverlong.Position memory) {
        return _portfolio.at(_index);
    }

    function positionCount() external view returns (uint256) {
        return _portfolio.positionCount();
    }

    function positionValue(uint256 _index) external view returns (uint256) {
        return _hyperdrive.previewCloseLong(_asBase, _portfolio.at(_index));
    }

    function avgMaturityTime() external view returns (uint128) {
        return _portfolio.avgMaturityTime;
    }

    function totalBonds() external view returns (uint128) {
        return _portfolio.totalBonds;
    }
}
