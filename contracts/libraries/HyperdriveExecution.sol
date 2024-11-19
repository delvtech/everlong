// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { HyperdriveMath } from "hyperdrive/contracts/src/libraries/HyperdriveMath.sol";
import { SafeCast } from "hyperdrive/contracts/src/libraries/SafeCast.sol";
import { YieldSpaceMath } from "hyperdrive/contracts/src/libraries/YieldSpaceMath.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Packing } from "openzeppelin/utils/Packing.sol";
import { IEverlongStrategy } from "../interfaces/IEverlongStrategy.sol";
import { IEverlongEvents } from "../interfaces/IEverlongEvents.sol";
import { ONE } from "./Constants.sol";

// TODO: Extract into its own library.
uint256 constant HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT = 2;
uint256 constant HYPERDRIVE_LONG_EXPOSURE_LONGS_OUTSTANDING_SLOT = 3;
uint256 constant HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT = 4;

/// @author DELV
/// @title HyperdriveExecutionLibrary
/// @notice Library to handle the execution of trades with hyperdrive.
/// @custom:disclaimer The language used in this code is for coding convenience
///                    only, and is not intended to, and does not, have any
///                    particular legal or regulatory significance.
library HyperdriveExecutionLibrary {
    using FixedPointMath for uint256;
    using SafeCast for *;
    using SafeERC20 for ERC20;
    using Packing for bytes32;

    // ╭─────────────────────────────────────────────────────────╮
    // │ Open Long                                               │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Opens a long with hyperdrive using amount.
    /// @param _asBase Whether to use hyperdrive's base asset.
    /// @param _amount Amount of assets to spend.
    /// @param _extraData Extra data to pass to hyperdrive.
    /// @return maturityTime Maturity timestamp of the opened position.
    /// @return bondAmount Amount of bonds received.
    function openLong(
        IHyperdrive self,
        bool _asBase,
        uint256 _amount,
        bytes memory _extraData
    ) internal returns (uint256 maturityTime, uint256 bondAmount) {
        (maturityTime, bondAmount) = self.openLong(
            _amount,
            0,
            0,
            IHyperdrive.Options(address(this), _asBase, _extraData)
        );
        emit IEverlongEvents.PositionOpened(
            maturityTime.toUint128(),
            bondAmount.toUint128()
        );
    }

    /// @dev Opens a long with hyperdrive using amount.
    /// @param _asBase Whether to use hyperdrive's base asset.
    /// @param _amount Amount of assets to spend.
    /// @param _minOutput Minimum amount of bonds to receive.
    /// @param _minVaultSharePrice Minimum hyperdrive vault share price.
    /// @param _extraData Extra data to pass to hyperdrive.
    /// @return maturityTime Maturity timestamp of the opened position.
    /// @return bondAmount Amount of bonds received.
    function openLong(
        IHyperdrive self,
        bool _asBase,
        uint256 _amount,
        uint256 _minOutput,
        uint256 _minVaultSharePrice,
        bytes memory _extraData
    ) internal returns (uint256 maturityTime, uint256 bondAmount) {
        (maturityTime, bondAmount) = self.openLong(
            _amount,
            _minOutput,
            _minVaultSharePrice,
            IHyperdrive.Options(address(this), _asBase, _extraData)
        );
        emit IEverlongEvents.PositionOpened(
            maturityTime.toUint128(),
            bondAmount.toUint128()
        );
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Close Long                                              │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Close a long with the input position's bond amount and maturity.
    /// @param _asBase Whether to receive hyperdrive's base token as output.
    /// @param _position Position information used to specify the long to close.
    /// @param _minOutput Minimum amount of assets to receive as output.
    /// @param _data Extra data to pass to hyperdrive.
    /// @return proceeds The amount of output assets received from closing the long.
    function closeLong(
        IHyperdrive self,
        bool _asBase,
        IEverlongStrategy.Position memory _position,
        uint256 _minOutput,
        bytes memory _data
    ) internal returns (uint256 proceeds) {
        proceeds = self.closeLong(
            _position.maturityTime,
            _position.bondAmount,
            _minOutput,
            IHyperdrive.Options(address(this), _asBase, _data)
        );
        emit IEverlongEvents.PositionClosed(
            _position.maturityTime,
            _position.bondAmount
        );
    }

    /// @dev Calculate the amount of output assets received from closing a
    ///         long.
    /// @dev Always less than or equal to the actual amount of assets received.
    /// @param _asBase Whether to receive hyperdrive's base token as output.
    /// @param _poolConfig Hyperdrive PoolConfig.
    /// @param _position Position information used to specify the long to close.
    /// @return The amount of output assets received from closing the long.
    function previewCloseLong(
        IHyperdrive self,
        bool _asBase,
        IHyperdrive.PoolConfig memory _poolConfig,
        IEverlongStrategy.Position memory _position,
        bytes memory // unused extradata
    ) internal view returns (uint256) {
        // Read select `PoolInfo` fields directly from Hyperdrive's storage to
        // save on gas costs.
        uint256[] memory slots = new uint256[](2);
        slots[0] = HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT;
        slots[1] = HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT;
        bytes32[] memory values = self.load(slots);
        uint256 shareProceeds = _calculateCloseLong(
            self,
            CalculateCloseLongParams({
                timeStretch: _poolConfig.timeStretch,
                initialVaultSharePrice: _poolConfig.initialVaultSharePrice,
                positionDuration: _poolConfig.positionDuration,
                curveFee: _poolConfig.fees.curve,
                flatFee: _poolConfig.fees.flat,
                shareReserves: uint128(values[0].extract_32_16(16)),
                bondReserves: uint128(values[0].extract_32_16(0)),
                shareAdjustment: uint256(uint128(values[1].extract_32_16(16)))
                    .toInt256()
            }),
            _position
        );
        if (_asBase) {
            return self.convertToBase(shareProceeds);
        }
        return shareProceeds;
    }

    struct CalculateCloseLongParams {
        uint256 timeStretch;
        uint256 initialVaultSharePrice;
        uint256 positionDuration;
        uint256 curveFee;
        uint256 flatFee;
        uint128 shareReserves;
        uint128 bondReserves;
        int256 shareAdjustment;
    }

    struct CalculateCloseLongData {
        uint256 effectiveShareReserves;
        uint256 normalizedTimeRemaining;
        uint256 openVaultSharePrice;
        uint256 closeVaultSharePrice;
        uint256 shareProceeds;
        uint256 spotPrice;
        uint256 curveFee;
        uint256 flatFee;
    }

    /// @dev Calculates the amount of output assets received from closing a
    ///      long. The process is as follows:
    ///        1. Calculates the raw amount using yield space.
    ///        2. Subtracts fees.
    ///        3. Accounts for negative interest.
    ///        4. Converts to shares and back to account for any rounding issues.
    /// @param _params Hyperdrive data needed for the calculation.
    /// @param _position Position containing information on the long to close.
    /// @return The amount of output assets received from closing the long.
    function _calculateCloseLong(
        IHyperdrive self,
        CalculateCloseLongParams memory _params,
        IEverlongStrategy.Position memory _position
    ) internal view returns (uint256) {
        // Use a struct to hold intermediate calculation results and avoid
        // stack-too-deep errors.
        CalculateCloseLongData memory data;

        // Prepare the necessary information to perform the yield space
        // calculation.
        data.effectiveShareReserves = HyperdriveMath
            .calculateEffectiveShareReserves(
                _params.shareReserves, // shareReserves
                _params.shareAdjustment // shareAdjustment
            );
        data.normalizedTimeRemaining = normalizedTimeRemaining(
            self,
            _position.maturityTime
        );

        // Hyperdrive uses the vaultSharePrice at the beginning of the
        // checkpoint as the open price, and the current vaultSharePrice as
        // the close price.
        data.closeVaultSharePrice = vaultSharePrice(self);
        data.openVaultSharePrice = getCheckpointDown(
            self,
            _position.maturityTime - _params.positionDuration
        ).vaultSharePrice;

        // Calculate the raw proceeds of the close without fees.
        (, , data.shareProceeds) = HyperdriveMath.calculateCloseLong(
            data.effectiveShareReserves,
            _params.bondReserves, // bondReserves
            _position.bondAmount,
            data.normalizedTimeRemaining,
            _params.timeStretch,
            data.closeVaultSharePrice,
            _params.initialVaultSharePrice
        );

        // Calculate the fees that should be paid by the trader. The trader
        // pays a fee on the curve and flat parts of the trade. Most of the
        // fees go the LPs, but a portion goes to governance.
        data.spotPrice = HyperdriveMath.calculateSpotPrice(
            data.effectiveShareReserves,
            _params.bondReserves,
            _params.initialVaultSharePrice,
            _params.timeStretch
        );
        (
            data.curveFee, // shares
            data.flatFee // shares
        ) = _calculateFeesGivenBonds(
            _position.bondAmount,
            data.normalizedTimeRemaining,
            data.spotPrice,
            data.closeVaultSharePrice,
            _params.curveFee,
            _params.flatFee
        );

        // Subtract fees from the proceeds.
        data.shareProceeds -= data.curveFee + data.flatFee;

        // Adjust the proceeds to account for negative interest.
        if (data.closeVaultSharePrice < data.openVaultSharePrice) {
            data.shareProceeds = data.shareProceeds.mulDivDown(
                data.closeVaultSharePrice,
                data.openVaultSharePrice
            );
        }

        // Correct for any error that crept into the calculation of the share
        // amount by converting the shares to base and then back to shares
        // using the vault's share conversion logic.
        data.shareProceeds = self.convertToShares(
            data.shareProceeds.mulDown(data.closeVaultSharePrice)
        );

        return data.shareProceeds;
    }

    /// @dev Calculates the fees that go to the LPs and governance.
    /// @param _bondAmount The amount of bonds being exchanged for shares.
    /// @param _normalizedTimeRemaining The normalized amount of time until
    ///        maturity.
    /// @param _spotPrice The price without slippage of bonds in terms of base
    ///        (base/bonds).
    /// @param _vaultSharePrice The current vault share price (base/shares).
    /// @return curveFee The curve fee. The fee is in terms of shares.
    /// @return flatFee The flat fee. The fee is in terms of shares.
    function _calculateFeesGivenBonds(
        uint256 _bondAmount,
        uint256 _normalizedTimeRemaining,
        uint256 _spotPrice,
        uint256 _vaultSharePrice,
        uint256 _curveFee,
        uint256 _flatFee
    ) internal pure returns (uint256 curveFee, uint256 flatFee) {
        // NOTE: Round up to overestimate the curve fee.
        //
        // p (spot price) tells us how many base a bond is worth -> p = base/bonds
        // 1 - p tells us how many additional base a bond is worth at
        // maturity -> (1 - p) = additional base/bonds
        //
        // The curve fee is taken from the additional base the user gets for
        // each bond at maturity:
        //
        // curve fee = ((1 - p) * phi_curve * d_y * t)/c
        //           = (base/bonds * phi_curve * bonds * t) / (base/shares)
        //           = (base/bonds * phi_curve * bonds * t) * (shares/base)
        //           = (base * phi_curve * t) * (shares/base)
        //           = phi_curve * t * shares
        curveFee = _curveFee
            .mulUp(ONE - _spotPrice)
            .mulUp(_bondAmount)
            .mulDivUp(_normalizedTimeRemaining, _vaultSharePrice);

        // NOTE: Round up to overestimate the flat fee.
        //
        // The flat portion of the fee is taken from the matured bonds.
        // Since a matured bond is worth 1 base, it is appropriate to consider
        // d_y in units of base:
        //
        // flat fee = (d_y * (1 - t) * phi_flat) / c
        //          = (base * (1 - t) * phi_flat) / (base/shares)
        //          = (base * (1 - t) * phi_flat) * (shares/base)
        //          = shares * (1 - t) * phi_flat
        uint256 flat = _bondAmount.mulDivUp(
            ONE - _normalizedTimeRemaining,
            _vaultSharePrice
        );
        flatFee = flat.mulUp(_flatFee);
    }

    /// @dev Obtains the vaultSharePrice from the hyperdrive instance.
    /// @return The current vaultSharePrice.
    function vaultSharePrice(IHyperdrive self) internal view returns (uint256) {
        return self.convertToBase(ONE);
    }

    /// @dev Returns whether a position is mature.
    /// @param _position Position to evaluate.
    /// @return True if the position is mature false otherwise.
    function isMature(
        IHyperdrive self,
        IEverlongStrategy.Position memory _position
    ) internal view returns (bool) {
        return isMature(self, _position.maturityTime);
    }

    /// @dev Returns whether a position is mature.
    /// @param _maturity Maturity to evaluate.
    /// @return True if the position is mature false otherwise.
    function isMature(
        IHyperdrive self,
        uint256 _maturity
    ) internal view returns (bool) {
        return normalizedTimeRemaining(self, _maturity) == 0;
    }

    /// @dev Converts the duration of the bond to a value between 0 and 1.
    /// @param _maturity Maturity time to evaluate.
    /// @return timeRemaining The normalized duration of the bond.
    function normalizedTimeRemaining(
        IHyperdrive self,
        uint256 _maturity
    ) internal view returns (uint256 timeRemaining) {
        // Use the latest checkpoint to calculate the time remaining if the
        // bond is not mature.
        timeRemaining = _maturity > latestCheckpoint(self)
            ? _maturity - latestCheckpoint(self)
            : 0;

        // Represent the time remaining as a fraction of the term.
        timeRemaining = timeRemaining.divDown(
            self.getPoolConfig().positionDuration
        );

        // Since we overestimate the time remaining to underestimate the
        // proceeds, there is an edge case where _normalizedTimeRemaining > 1
        // if the position was opened in the same checkpoint. For this case,
        // we can just set it to ONE.
        if (timeRemaining > ONE) {
            timeRemaining = ONE;
        }
    }

    /// @dev Retrieve the latest checkpoint time from the hyperdrive instance.
    /// @return The latest checkpoint time.
    function latestCheckpoint(
        IHyperdrive self
    ) internal view returns (uint256) {
        return
            HyperdriveMath.calculateCheckpointTime(
                uint256(block.timestamp),
                self.getPoolConfig().checkpointDuration
            );
    }

    /// @dev Returns the closest checkpoint timestamp before _timestamp.
    /// @param _timestamp The timestamp to search for checkpoints.
    /// @return The closest checkpoint timestamp.
    function getCheckpointIdDown(
        IHyperdrive self,
        uint256 _timestamp
    ) internal view returns (uint256) {
        return
            _timestamp - (_timestamp % self.getPoolConfig().checkpointDuration);
    }

    /// @dev Returns the closest checkpoint before _timestamp.
    /// @param _timestamp The timestamp to search for checkpoints.
    /// @return The closest checkpoint.
    function getCheckpointDown(
        IHyperdrive self,
        uint256 _timestamp
    ) internal view returns (IHyperdrive.Checkpoint memory) {
        return self.getCheckpoint(getCheckpointIdDown(self, _timestamp));
    }

    /// @dev Returns the closest checkpoint timestamp after _timestamp.
    /// @param _timestamp The timestamp to search for checkpoints.
    /// @return The closest checkpoint timestamp.
    function getCheckpointIdUp(
        IHyperdrive self,
        uint256 _timestamp
    ) internal view returns (uint256) {
        uint256 _checkpointDuration = self.getPoolConfig().checkpointDuration;
        return
            _timestamp +
            (_checkpointDuration - (_timestamp % _checkpointDuration));
    }

    /// @dev Returns the closest checkpoint after _timestamp.
    /// @param _timestamp The timestamp to search for checkpoints.
    /// @return The closest checkpoint.
    function getCheckpointUp(
        IHyperdrive self,
        uint256 _timestamp
    ) internal view returns (IHyperdrive.Checkpoint memory) {
        return self.getCheckpoint(getCheckpointIdUp(self, _timestamp));
    }
}
