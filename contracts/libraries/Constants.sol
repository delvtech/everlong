// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/// @dev Wad used for fixed point math.
uint256 constant ONE = 1e18;

/// @dev Maximum basis points value (10_000 == 100%).
uint256 constant MAX_BPS = 10_000;

/// @dev Yearn RoleManagerFactory address for mainnet, base, and arbitrum.
address constant ROLE_MANAGER_FACTORY_ADDRESS = 0xca12459a931643BF28388c67639b3F352fe9e5Ce;

/// @dev Yearn CommonReportTrigger address for mainnet, base, and arbitrum.
address constant COMMON_REPORT_TRIGGER_ADDRESS = 0xA045D4dAeA28BA7Bfe234c96eAa03daFae85A147;

/// @dev Version the contract was deployed with.
string constant EVERLONG_VERSION = "v0.0.1";

/// @dev Kind for the Everlong strategy.
string constant EVERLONG_STRATEGY_KIND = "EverlongStrategy";

/// @dev Kind for the Everlong strategy keeper contract.
string constant EVERLONG_STRATEGY_KEEPER_KIND = "EverlongStrategyKeeper";
