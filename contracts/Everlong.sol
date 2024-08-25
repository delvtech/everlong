// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { IEverlong } from "./interfaces/IEverlong.sol";
import { EverlongAdmin } from "./internal/EverlongAdmin.sol";
import { EverlongBase } from "./internal/EverlongBase.sol";
import { EverlongERC4626 } from "./internal/EverlongERC4626.sol";
import { EverlongPositions } from "./internal/EverlongPositions.sol";
import { EVERLONG_KIND, EVERLONG_VERSION } from "./libraries/Constants.sol";

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
//
/// @author DELV
/// @title Everlong
/// @notice A money market powered by Hyperdrive.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
contract Everlong is EverlongAdmin, EverlongPositions, EverlongERC4626 {
    // ╭─────────────────────────────────────────────────────────╮
    // │ Constructor                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Initial configuration paramters for EverlongERC4626.
    /// @param __name Name of the ERC20 token managed by Everlong.
    /// @param __symbol Symbol of the ERC20 token managed by Everlong.
    /// @param __hyperdrive Address of the Hyperdrive instance.
    /// @param __asBase Whether to use the base or shares token from Hyperdrive.
    constructor(
        string memory __name,
        string memory __symbol,
        address __hyperdrive,
        bool __asBase
    ) {
        // Store constructor parameters.
        _name = __name;
        _symbol = __symbol;
        _hyperdrive = __hyperdrive;
        _asBase = __asBase;
        _asset = __asBase
            ? IHyperdrive(__hyperdrive).baseToken()
            : IHyperdrive(__hyperdrive).vaultSharesToken();

        // Attempt to retrieve the decimals from the {_asset} contract.
        // If it does not implement `decimals() (uint256)`, use the default.
        (bool success, uint8 result) = _tryGetAssetDecimals(_asset);
        _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Gets the Everlong instance's kind.
    /// @return The Everlong instance's kind.
    function kind() external view returns (string memory) {
        return EVERLONG_KIND;
    }

    /// @notice Gets the Everlong instance's version.
    /// @return The Everlong instance's version.
    function version() external view returns (string memory) {
        return EVERLONG_VERSION;
    }

    /// @notice Gets the address of the underlying Hyperdrive Instance
    function hyperdrive() external view returns (address) {
        return _hyperdrive;
    }
}
