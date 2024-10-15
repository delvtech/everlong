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
import { IEverlong } from "../interfaces/IEverlong.sol";
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
    /// @return maturityTime Maturity timestamp of the opened position.
    /// @return bondAmount Amount of bonds received.
    function openLong(
        IHyperdrive self,
        bool _asBase,
        uint256 _amount,
        bytes memory // unused extra data
    ) internal returns (uint256 maturityTime, uint256 bondAmount) {
        // TODO: Slippage
        (maturityTime, bondAmount) = self.openLong(
            _amount,
            0,
            0,
            IHyperdrive.Options(address(this), _asBase, "")
        );
        emit IEverlongEvents.PositionOpened(
            maturityTime.toUint128(),
            bondAmount.toUint128()
        );
    }

    /// @dev Calculates the result of opening a long with hyperdrive.
    /// @param _asBase Whether to use hyperdrive's base asset.
    /// @param _amount Amount of assets to spend.
    /// @return Amount of bonds received.
    function previewOpenLong(
        IHyperdrive self,
        bool _asBase,
        uint256 _amount,
        bytes memory // unused extra data
    ) internal view returns (uint256) {
        return
            _calculateOpenLong(
                self,
                _asBase ? self.convertToShares(_amount) : _amount
            );
    }

    /// @dev Calculates the amount of output bonds received from opening a
    ///      long. The process is as follows:
    ///        1. Calculates the raw amount using yield space.
    ///        2. Subtracts fees.
    /// @param _shareAmount Amount of shares being exchanged for bonds.
    /// @return Amount of bonds received.
    function _calculateOpenLong(
        IHyperdrive self,
        uint256 _shareAmount
    ) internal view returns (uint256) {
        // We must load the entire PoolConfig since it contains values from
        // immutables without public accessors.
        IHyperdrive.PoolConfig memory poolConfig = self.getPoolConfig();

        // Prepare the necessary information to perform the yield space
        // calculation. We save gas by reading storage directly instead of
        // retrieving entire PoolInfo struct.
        uint256[] memory slots = new uint256[](2);
        slots[0] = HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT;
        slots[1] = HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT;
        bytes32[] memory values = self.load(slots);
        uint256 effectiveShareReserves = HyperdriveMath
            .calculateEffectiveShareReserves(
                uint128(values[0].extract_32_16(16)), // shareReserves
                uint256(uint128(values[1].extract_32_16(16))).toInt256() // shareAdjustment
            );
        uint256 bondReserves = uint128(values[0].extract_32_16(0));
        uint256 _vaultSharePrice = vaultSharePrice(self);

        // Calculate the change in hyperdrive's bond reserves given a purchase
        // of _shareAmount. This amount is equivalent to the amount of bonds
        // the purchaser will receive (not accounting for fees).
        uint256 bondReservesDelta = YieldSpaceMath
            .calculateBondsOutGivenSharesInDown(
                effectiveShareReserves,
                bondReserves,
                _shareAmount,
                // NOTE: Since the bonds traded on the curve are newly minted,
                // we use a time remaining of 1. This means that we can use
                // `_timeStretch = t * _timeStretch`.
                ONE - poolConfig.timeStretch,
                _vaultSharePrice,
                poolConfig.initialVaultSharePrice
            );

        // Apply fees to the output bond amount and return it.
        uint256 spotPrice = HyperdriveMath.calculateSpotPrice(
            effectiveShareReserves,
            bondReserves,
            poolConfig.initialVaultSharePrice,
            poolConfig.timeStretch
        );
        bondReservesDelta = _calculateOpenLongFees(
            _shareAmount,
            bondReservesDelta,
            _vaultSharePrice,
            spotPrice,
            poolConfig.fees.curve
        );
        return bondReservesDelta;
    }

    /// @dev Calculate the fees involved with opening the long and apply them.
    /// @param _shareReservesDelta The change in the share reserves without fees.
    /// @param _bondReservesDelta The change in the bond reserves without fees.
    /// @param _vaultSharePrice The current vault share price.
    /// @param _spotPrice The current spot price.
    /// @return The change in the bond reserves with fees.
    function _calculateOpenLongFees(
        uint256 _shareReservesDelta,
        uint256 _bondReservesDelta,
        uint256 _vaultSharePrice,
        uint256 _spotPrice,
        uint256 _curveFee
    ) internal pure returns (uint256) {
        // Calculate the fees charged to the user (curveFee).
        uint256 curveFee = _calculateFeesGivenShares(
            _shareReservesDelta,
            _spotPrice,
            _vaultSharePrice,
            _curveFee
        );

        // Calculate the impact of the curve fee on the bond reserves. The curve
        // fee benefits the LPs by causing less bonds to be deducted from the
        // bond reserves.
        _bondReservesDelta -= curveFee;

        return (_bondReservesDelta);
    }

    // ╭─────────────────────────────────────────────────────────╮
    // │ Close Long                                              │
    // ╰─────────────────────────────────────────────────────────╯

    /// @dev Close a long with the input position's bond amount and maturity.
    /// @param _asBase Whether to receive hyperdrive's base token as output.
    /// @param _position Position information used to specify the long to close.
    /// @return proceeds The amount of output assets received from closing the long.
    function closeLong(
        IHyperdrive self,
        bool _asBase,
        IEverlong.Position memory _position,
        bytes memory // unused extradata
    ) internal returns (uint256 proceeds) {
        // TODO: Slippage
        proceeds = self.closeLong(
            _position.maturityTime,
            _position.bondAmount,
            0,
            IHyperdrive.Options(address(this), _asBase, "")
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
    /// @param _position Position information used to specify the long to close.
    /// @return The amount of output assets received from closing the long.
    function previewCloseLong(
        IHyperdrive self,
        bool _asBase,
        IEverlong.Position memory _position,
        bytes memory // unused extradata
    ) internal view returns (uint256) {
        return previewCloseLong(self, _asBase, _position, spotPrice(self), "");
    }

    /// @dev Calculate the amount of output assets received from closing a
    ///         long.
    /// @dev Always less than or equal to the actual amount of assets received.
    /// @param _asBase Whether to receive hyperdrive's base token as output.
    /// @param _position Position information used to specify the long to close.
    /// @param _spotPrice The spot price to use for calculations.
    /// @return The amount of output assets received from closing the long.
    function previewCloseLong(
        IHyperdrive self,
        bool _asBase,
        IEverlong.Position memory _position,
        uint256 _spotPrice,
        bytes memory // unused extradata
    ) internal view returns (uint256) {
        uint256 shareProceeds = _calculateCloseLong(
            self,
            _position,
            _spotPrice
        );
        if (_asBase) {
            return self.convertToBase(shareProceeds);
        }
        return shareProceeds;
    }

    /// @dev Calculates the amount of output assets received from closing a
    ///      long. The process is as follows:
    ///        1. Calculates the raw amount using yield space.
    ///        2. Subtracts fees.
    ///        3. Accounts for negative interest.
    ///        4. Converts to shares and back to account for any rounding issues.
    /// @param _position Position containing information on the long to close.
    /// @param _spotPrice The spot price of the bonds to use for calculations.
    /// @return The amount of output assets received from closing the long.
    function _calculateCloseLong(
        IHyperdrive self,
        IEverlong.Position memory _position,
        uint256 _spotPrice
    ) internal view returns (uint256) {
        // We must load the entire PoolConfig since it contains values from
        // immutables without public accessors.
        IHyperdrive.PoolConfig memory poolConfig = self.getPoolConfig();

        // Prepare the necessary information to perform the yield space
        // calculation. We save gas by reading storage directly instead of
        // retrieving entire PoolInfo struct.
        uint256[] memory slots = new uint256[](2);
        slots[0] = HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT;
        slots[1] = HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT;
        bytes32[] memory values = self.load(slots);
        uint256 effectiveShareReserves = HyperdriveMath
            .calculateEffectiveShareReserves(
                uint128(values[0].extract_32_16(16)), // shareReserves
                uint256(uint128(values[1].extract_32_16(16))).toInt256() // shareAdjustment
            );
        uint256 _normalizedTimeRemaining = normalizedTimeRemaining(
            self,
            _position.maturityTime
        );

        // Hyperdrive uses the vaultSharePrice at the beginning of the
        // checkpoint as the open price, and the current vaultSharePrice as
        // the close price.
        uint256 closeVaultSharePrice = vaultSharePrice(self);
        uint256 openVaultSharePrice = getCheckpointDown(
            self,
            _position.maturityTime - poolConfig.positionDuration
        ).vaultSharePrice;

        // Calculate the raw proceeds of the close without fees.
        (, , uint256 shareProceeds) = HyperdriveMath.calculateCloseLong(
            effectiveShareReserves,
            uint128(values[0].extract_32_16(0)), // bondReserves
            _position.bondAmount,
            _normalizedTimeRemaining,
            poolConfig.timeStretch,
            closeVaultSharePrice,
            poolConfig.initialVaultSharePrice
        );

        // Calculate the fees that should be paid by the trader. The trader
        // pays a fee on the curve and flat parts of the trade. Most of the
        // fees go the LPs, but a portion goes to governance.
        IHyperdrive.Fees memory fees = poolConfig.fees;
        (
            uint256 curveFee, // shares
            uint256 flatFee // shares
        ) = _calculateFeesGivenBonds(
                _position.bondAmount,
                _normalizedTimeRemaining,
                _spotPrice,
                closeVaultSharePrice,
                fees.curve,
                fees.flat
            );

        // Subtract fees from the proceeds.
        shareProceeds -= curveFee + flatFee;

        // Adjust the proceeds to account for negative interest.
        if (closeVaultSharePrice < openVaultSharePrice) {
            shareProceeds = shareProceeds.mulDivDown(
                closeVaultSharePrice,
                openVaultSharePrice
            );
        }

        // Correct for any error that crept into the calculation of the share
        // amount by converting the shares to base and then back to shares
        // using the vault's share conversion logic.
        shareProceeds = self.convertToShares(
            shareProceeds.mulDown(closeVaultSharePrice)
        );

        return shareProceeds;
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

    /// @dev Calculates the fees that go to the LPs and governance.
    /// @dev See `lib/hyperdrive/contracts/src/internal/HyperdriveBase.sol`
    ///      for more information.
    /// @param _shareAmount The amount of shares exchanged for bonds.
    /// @param _spotPrice The price without slippage of bonds in terms of base
    ///         (base/bonds).
    /// @param _vaultSharePrice The current vault share price (base/shares).
    /// @return curveFee The curve fee. The fee is in terms of bonds.
    function _calculateFeesGivenShares(
        uint256 _shareAmount,
        uint256 _spotPrice,
        uint256 _vaultSharePrice,
        uint256 _curveFee
    ) internal pure returns (uint256 curveFee) {
        // NOTE: Round up to overestimate the curve fee.
        //
        // Fixed Rate (r) = (value at maturity - purchase price)/(purchase price)
        //                = (1-p)/p
        //                = ((1 / p) - 1)
        //                = the ROI at maturity of a bond purchased at price p
        //
        // Another way to think about it:
        //
        // p (spot price) tells us how many base a bond is worth -> p = base/bonds
        // 1/p tells us how many bonds a base is worth -> 1/p = bonds/base
        // 1/p - 1 tells us how many additional bonds we get for each
        // base -> (1/p - 1) = additional bonds/base
        //
        // The curve fee is taken from the additional bonds the user gets for
        // each base:
        //
        // curve fee = ((1 / p) - 1) * phi_curve * c * dz
        //           = r * phi_curve * base/shares * shares
        //           = bonds/base * phi_curve * base
        //           = bonds * phi_curve
        curveFee = (uint256(ONE).divUp(_spotPrice) - ONE)
            .mulUp(_curveFee)
            .mulUp(_vaultSharePrice)
            .mulUp(_shareAmount);
    }

    // TODO: Use cached poolConfig.
    //
    /// @dev Calculates the current spot price of a long.
    /// @return The current spot price.
    function spotPrice(IHyperdrive self) internal view returns (uint256) {
        IHyperdrive.PoolConfig memory poolConfig = self.getPoolConfig();

        // Read hyperdrive configuration parameters directly from storage.
        uint256[] memory slots = new uint256[](2);
        slots[0] = HYPERDRIVE_SHARE_RESERVES_BOND_RESERVES_SLOT;
        slots[1] = HYPERDRIVE_SHARE_ADJUSTMENT_SHORTS_OUTSTANDING_SLOT;
        bytes32[] memory values = self.load(slots);

        // Calculate the effective share reserves.
        uint256 effectiveShareReserves = HyperdriveMath
            .calculateEffectiveShareReserves(
                uint128(values[0].extract_32_16(16)), // shareReserves
                uint256(uint128(values[1].extract_32_16(16))).toInt256() // shareAdjustment
            );

        // Calculate the current spot price.
        return
            HyperdriveMath.calculateSpotPrice(
                effectiveShareReserves,
                uint128(values[0].extract_32_16(0)), // bondReserves
                poolConfig.initialVaultSharePrice,
                poolConfig.timeStretch
            );
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
        IEverlong.Position memory _position
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
