// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IEverlong } from "../../contracts/interfaces/IEverlong.sol";
import { Everlong } from "../../contracts/Everlong.sol";
import { Portfolio } from "../../contracts/libraries/Portfolio.sol";

/// @title EverlongPortfolioExposed
/// @dev Exposes all internal functions for the `EverlongPositions` contract.
abstract contract EverlongPortfolioExposed is Everlong {
    using Portfolio for Portfolio.State;

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
