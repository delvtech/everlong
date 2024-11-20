// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// WARN: Directly importing `Accountant.sol` from vault-periphery results in
//       solidity compiler errors, so needed methods are copied here.
interface IAccountant {
    /// @notice Struct representing fee details.
    struct Fee {
        uint16 managementFee; // Annual management fee to charge.
        uint16 performanceFee; // Performance fee to charge.
        uint16 refundRatio; // Refund ratio to give back on losses.
        uint16 maxFee; // Max fee allowed as a percent of gain.
        uint16 maxGain; // Max percent gain a strategy can report.
        uint16 maxLoss; // Max percent loss a strategy can report.
        bool custom; // Flag to set for custom configs.
    }

    /// @notice Sets the `maxLoss` parameter to be used on redeems.
    /// @param _maxLoss The amount in basis points to set as the maximum loss.
    function setMaxLoss(uint256 _maxLoss) external;

    /// @notice The amount of max loss to use when redeeming from vaults.
    function maxLoss() external view returns (uint256);

    /// @notice The default fee configuration.
    function defaultConfig() external view returns (Fee memory);

    /// @notice Function to update the default fee configuration used for
    ///    all strategies that don't have a custom config set.
    /// @param defaultManagement Default annual management fee to charge.
    /// @param defaultPerformance Default performance fee to charge.
    /// @param defaultRefund Default refund ratio to give back on losses.
    /// @param defaultMaxFee Default max fee to allow as a percent of gain.
    /// @param defaultMaxGain Default max percent gain a strategy can report.
    /// @param defaultMaxLoss Default max percent loss a strategy can report.
    function updateDefaultConfig(
        uint16 defaultManagement,
        uint16 defaultPerformance,
        uint16 defaultRefund,
        uint16 defaultMaxFee,
        uint16 defaultMaxGain,
        uint16 defaultMaxLoss
    ) external;

    /// @notice Function to accept the role change and become the new fee manager.
    /// @dev This function allows the future fee manager to accept the role change and become the new fee manager.
    function acceptFeeManager() external;

    /// @notice Function to add a new vault for this accountant to charge fees for.
    /// @dev This is not used to set any of the fees for the specific vault or strategy. Each fee will be set separately.
    /// @param vault The address of a vault to allow to use this accountant.
    function addVault(address vault) external;

    /// @notice The address of the fee manager.
    function feeManager() external view returns (address);

    /// @notice The address of the future fee manager.
    function futureFeeManager() external view returns (address);
}
