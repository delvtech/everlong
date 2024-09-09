// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";
import { Everlong } from "../../contracts/Everlong.sol";

/// @title EverlongExposed
/// @dev Exposes all internal functions for the `Everlong` contract.
contract EverlongExposed is Everlong, Test {
    using Portfolio for Portfolio.State;

    /// @notice Initial configuration paramters for Everlong.
    /// @param hyperdrive_ Address of the Hyperdrive instance wrapped by Everlong.
    /// @param name_ Name of the ERC20 token managed by Everlong.
    /// @param symbol_ Symbol of the ERC20 token managed by Everlong.
    /// @param decimals_ Decimals of the Everlong token and Hyperdrive token.
    /// @param asBase_ Whether to use Hyperdrive's base token for bond purchases.
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address hyperdrive_,
        bool asBase_
    ) Everlong(name_, symbol_, decimals_, hyperdrive_, asBase_) {}

    // ╭─────────────────────────────────────────────────────────╮
    // │ ERC4626                                                 │
    // ╰─────────────────────────────────────────────────────────╯

    function exposed_beforeWithdraw(uint256 _assets, uint256 _shares) public {
        return _beforeWithdraw(_assets, _shares);
    }

    function exposed_afterDeposit(uint256 _assets, uint256 _shares) public {
        return _afterDeposit(_assets, _shares);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Portfolio                                               │
    // ╰─────────────────────────────────────────────────────────╯

    function exposed_handleOpenPosition(
        IEverlong.Position memory _position
    ) public {
        _portfolio.handleOpenPosition(
            _position.maturityTime,
            _position.bondAmount
        );
    }

    function exposed_handleOpenPosition(
        uint256 _maturityTime,
        uint256 _bondAmount
    ) public {
        _portfolio.handleOpenPosition(_maturityTime, _bondAmount);
    }

    function exposed_handleClosePosition() public {
        _portfolio.handleClosePosition();
    }
}
