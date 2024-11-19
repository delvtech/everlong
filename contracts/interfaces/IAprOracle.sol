// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IAprOracle {
    /**
     * @notice Get the current APR a strategy is earning.
     * @dev Will revert if an oracle has not been set for that strategy.
     *
     * This will be different than the {getExpectedApr()} which returns
     * the current APR based off of previously reported profits that
     * are currently unlocking.
     *
     * This will return the APR the strategy is currently earning that
     * has yet to be reported.
     *
     * @param _strategy Address of the strategy to check.
     * @param _debtChange Positive or negative change in debt.
     * @return apr The expected APR it will be earning represented as 1e18.
     */
    function getStrategyApr(
        address _strategy,
        int256 _debtChange
    ) external view returns (uint256 apr);
    /**
     * @notice Get the current weighted APR of a strategy.
     * @dev Gives the apr weighted by its `totalAssets`. This can be used
     * to get the combined expected return of a collection of strategies.
     *
     * @param _strategy Address of the strategy.
     * @return . The current weighted APR of the strategy.
     */
    function weightedApr(address _strategy) external view returns (uint256);

    /**
     * @notice Set a custom APR `_oracle` for a `_strategy`.
     * @dev Can only be called by the oracle's `governance` or
     *  management of the `_strategy`.
     *
     * The `_oracle` will need to implement the IOracle interface.
     *
     * @param _strategy Address of the strategy.
     * @param _oracle Address of the APR Oracle.
     */
    function setOracle(address _strategy, address _oracle) external;

    /**
     * @notice Get the current APR for a V3 vault or strategy.
     * @dev This returns the current APR based off the current
     * rate of profit unlocking for either a vault or strategy.
     *
     * Will return 0 if there is no profit unlocking or no assets.
     *
     * @param _vault The address of the vault or strategy.
     * @return apr The current apr expressed as 1e18.
     */
    function getCurrentApr(address _vault) external view returns (uint256 apr);

    /**
     * @notice Get the expected APR for a V3 vault or strategy based on `_delta`.
     * @dev This returns the expected APR based off the current
     * rate of profit unlocking for either a vault or strategy
     * given some change in the total assets.
     *
     * Will return 0 if there is no profit unlocking or no assets.
     *
     * This can be used to predict the change in current apr given some
     * deposit or withdraw to the vault.
     *
     * @param _vault The address of the vault or strategy.
     * @param _delta The positive or negative change in `totalAssets`.
     * @return apr The expected apr expressed as 1e18.
     */
    function getExpectedApr(
        address _vault,
        int256 _delta
    ) external view returns (uint256 apr);
}
