// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { ERC4626 } from "solady/tokens/ERC4626.sol";

/// @author DELV
/// @title EverlongERC4626
/// @notice Everlong ERC4626 implementation.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongERC4626 is ERC4626 {
    /// @notice Virtual shares are used to mitigate inflation attacks.
    bool public constant useVirtualShares = true;

    /// @notice Used to reduce the feasibility of an inflation attack.
    /// TODO: Determine the appropriate value for our case. Current value
    ///       was picked arbitrarily.
    uint8 public constant decimalsOffset = 3;

    /// @dev Address of the token to use for Hyperdrive bond purchase/close.
    address internal immutable _asset;

    /// @dev Decimals used by the `_asset`.
    uint8 internal immutable _decimals;

    /// @dev Name of the Everlong token.
    string internal _name;

    /// @dev Symbol of the Everlong token.
    string internal _symbol;

    /// @notice Initial configuration paramters for EverlongERC4626.
    /// @param name_ Name of the ERC20 token managed by Everlong.
    /// @param symbol_ Symbol of the ERC20 token managed by Everlong.
    /// @param asset_ Base token used by Everlong for deposits/withdrawals.
    constructor(string memory name_, string memory symbol_, address asset_) {
        // Store constructor parameters.
        _name = name_;
        _symbol = symbol_;
        _asset = asset_;

        // Attempt to retrieve the decimals from the {_asset} contract.
        // If it does not implement `decimals() (uint256)`, use the default.
        (bool success, uint8 result) = _tryGetAssetDecimals(asset_);
        _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;
    }

    /// @notice Address of the token to use for deposits/withdrawals.
    /// @dev MUST be an ERC20 token contract.
    /// @return Asset address.
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
}
