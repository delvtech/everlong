// SPDX-License-Identifier: GNU AGPLv3
pragma solidity ^0.8.20;

interface IAccountant {
    function feeManager() external view returns (address);
    /**
     * @notice Turn off the health check for a specific `vault` `strategy` combo.
     * @dev This will only last for one report and get automatically turned back on.
     * @param vault Address of the vault.
     * @param strategy Address of the strategy.
     */
    function turnOffHealthCheck(address vault, address strategy) external;
}
