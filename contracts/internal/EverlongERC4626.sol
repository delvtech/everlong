// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.22;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { HyperdriveUtils } from "hyperdrive/test/utils/HyperdriveUtils.sol";
import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { ERC4626 } from "solady/tokens/ERC4626.sol";
import { EverlongPositions } from "./EverlongPositions.sol";

/// @author DELV
/// @title EverlongERC4626
/// @notice Everlong ERC4626 implementation.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
abstract contract EverlongERC4626 is ERC4626, EverlongPositions {
    // ╭─────────────────────────────────────────────────────────╮
    // │ Constructor                                             │
    // ╰─────────────────────────────────────────────────────────╯

    /// @notice Initial configuration paramters for EverlongERC4626.
    /// @param __name Name of the ERC20 token managed by Everlong.
    /// @param __symbol Symbol of the ERC20 token managed by Everlong.
    /// @param __asset Base token used by Everlong for deposits/withdrawals.
    constructor(string memory __name, string memory __symbol, address __asset) {
        // Store constructor parameters.
        _name = __name;
        _symbol = __symbol;
        _asset = __asset;

        // Attempt to retrieve the decimals from the {_asset} contract.
        // If it does not implement `decimals() (uint256)`, use the default.
        (bool success, uint8 result) = _tryGetAssetDecimals(__asset);
        _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Stateful                                                │
    // ╰─────────────────────────────────────────────────────────╯

    /// @inheritdoc ERC4626
    function redeem(
        uint256 shares,
        address to,
        address owner
    ) public override returns (uint256 assets) {
        assets = super.redeem(shares, to, owner);
        rebalance();
    }

    // TODO: Implement.
    /// @inheritdoc ERC4626
    function mint(uint256, address) public override returns (uint256 assets) {
        revert("mint not implemented, please use deposit");
    }

    // TODO: Implement.
    /// @inheritdoc ERC4626
    function withdraw(
        uint256,
        address,
        address
    ) public override returns (uint256 shares) {
        revert("withdraw not implemented, please use redeem");
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Overrides                                               │
    // ╰─────────────────────────────────────────────────────────╯

    // TODO: Actually estimate this based on current position contents.
    //       Currently, this is obtained from tracking deposits - withdrawals
    //       which results in Everlong taking all profit and users receiving
    //       exactly what they put in.
    /// @notice Returns the total value of assets managed by Everlong.
    /// @return Total managed asset value.
    function totalAssets() public view override returns (uint256) {
        return _virtualAssets;
    }

    /// @inheritdoc ERC4626
    function maxDeposit(
        address
    ) public view override returns (uint256 maxAssets) {
        maxAssets = HyperdriveUtils.calculateMaxLong(IHyperdrive(hyperdrive));
    }

    /// @dev Decrement the virtual assets and close sufficient positions to
    ///      service the withdrawal.
    /// @param _assets Amount of assets owed to the withdrawer.
    function _beforeWithdraw(
        uint256 _assets,
        uint256
    ) internal virtual override {
        _virtualAssets -= _assets;
        // Check if Everlong has sufficient assets to service the withdrawal.
        if (IERC20(_asset).balanceOf(address(this)) < _assets) {
            // Everlong does not have sufficient assets to service withdrawal.
            // First try closing all mature positions. If sufficient to
            // service the withdrawal, then continue.
            _closeMaturedPositions();
            uint256 _currentBalance = IERC20(_asset).balanceOf(address(this));
            if (_currentBalance >= _assets) return;

            // Close remaining positions until Everlong's balance is
            // enough to meet the withdrawal.
            _closePositionsByOutput(_assets - _currentBalance);
        }
    }

    /// @dev Increment the virtual assets and rebalance positions to use
    ///      the newly-deposited liquidity.
    /// @param _assets Amount of assets deposited.
    function _afterDeposit(uint256 _assets, uint256) internal virtual override {
        _virtualAssets += _assets;
        rebalance();
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Internal                                                │
    // ╰─────────────────────────────────────────────────────────╯

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

    // ╭─────────────────────────────────────────────────────────╮
    // │ Getters                                                 │
    // ╰─────────────────────────────────────────────────────────╯

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
}
