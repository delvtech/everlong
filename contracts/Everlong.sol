// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { EverlongAdmin } from "./internal/EverlongAdmin.sol";
import { EverlongBase } from "./internal/EverlongBase.sol";
import { EverlongPositions } from "./internal/EverlongPositions.sol";

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
contract Everlong is EverlongAdmin, EverlongPositions {
    /// @notice Initial configuration paramters for Everlong.
    /// @param _name Name of the ERC20 token managed by Everlong.
    /// @param _symbol Symbol of the ERC20 token managed by Everlong.
    /// @param __hyperdrive Address of the Hyperdrive instance wrapped by Everlong.
    /// @param __asBase Whether to use Hyperdrive's base token for bond purchases.
    constructor(
        string memory _name,
        string memory _symbol,
        address __hyperdrive,
        bool __asBase
    ) EverlongBase(_name, _symbol, __hyperdrive, __asBase) {}
}
