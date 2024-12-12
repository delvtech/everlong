// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { console2 as console } from "forge-std/console2.sol";
import { IERC20, IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { ISwapRouter } from "hyperdrive/contracts/src/interfaces/ISwapRouter.sol";
import { IUniV3Zap } from "hyperdrive/contracts/src/interfaces/IUniV3Zap.sol";
import { IWETH } from "hyperdrive/contracts/src/interfaces/IWETH.sol";
import { FixedPointMath } from "hyperdrive/contracts/src/libraries/FixedPointMath.sol";
import { UniV3Zap } from "hyperdrive/contracts/src/zaps/UniV3Zap.sol";
import { Lib } from "hyperdrive/test/utils/Lib.sol";
import { IVault } from "yearn-vaults-v3/interfaces/IVault.sol";
import { IEverlongStrategy } from "../../../contracts/interfaces/IEverlongStrategy.sol";
import { IPermissionedStrategy } from "../../../contracts/interfaces/IPermissionedStrategy.sol";
import { MAX_BPS } from "../../../contracts/libraries/Constants.sol";
import { HyperdriveExecutionLibrary } from "../../../contracts/libraries/HyperdriveExecution.sol";
import { EverlongStrategy } from "../../../contracts/EverlongStrategy.sol";
import { EverlongTest } from "../EverlongTest.sol";

/// @dev Test ensuring that Everlong works with UniV3 zaps when interacting with
///      hyperdrive
contract TestZap is EverlongTest {
    using FixedPointMath for *;
    using Lib for *;
    using HyperdriveExecutionLibrary for *;

    /// @dev Uniswap's lowest fee tier.
    uint24 internal constant LOWEST_FEE_TIER = 100;

    /// @dev Uniswap's low fee tier.
    uint24 internal constant LOW_FEE_TIER = 500;

    /// @dev Uniswap's medium fee tier.
    uint24 internal constant MEDIUM_FEE_TIER = 3_000;

    /// @dev Uniswap's high fee tier.
    uint24 internal constant HIGH_FEE_TIER = 10_000;

    /// @dev The USDC token address.
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @dev The DAI token address.
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    /// @dev The sDAI token address.
    address internal constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    /// @dev The Wrapped Ether token address.
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev The rETH token address.
    address internal constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;

    /// @dev The stETH token address.
    address internal constant STETH =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    /// @dev The wstETH token address.
    address internal constant WSTETH =
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    /// @dev The USDC whale address
    address internal constant USDC_WHALE =
        0xDFd5293D8e347dFe59E90eFd55b2956a1343963d;

    /// @dev The DAI whale address
    address internal constant DAI_WHALE =
        0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf;

    /// @dev The sDAI whale address
    address internal constant SDAI_WHALE =
        0x4C612E3B15b96Ff9A6faED838F8d07d479a8dD4c;

    /// @dev The WETH whale address
    address internal constant WETH_WHALE =
        0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;

    /// @dev The rETH whale address
    address internal constant RETH_WHALE =
        0xCc9EE9483f662091a1de4795249E24aC0aC2630f;

    /// @dev The stETH whale address
    address internal constant STETH_WHALE =
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    /// @dev The Uniswap swap router.
    ISwapRouter internal constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /// @dev The Hyperdrive mainnet sDAI pool.
    IHyperdrive internal constant SDAI_HYPERDRIVE =
        IHyperdrive(0x324395D5d835F84a02A75Aa26814f6fD22F25698);

    /// @dev The Hyperdrive mainnet stETH pool.
    IHyperdrive internal constant STETH_HYPERDRIVE =
        IHyperdrive(0xd7e470043241C10970953Bd8374ee6238e77D735);

    /// @dev The Hyperdrive mainnet rETH pool.
    IHyperdrive internal constant RETH_HYPERDRIVE =
        IHyperdrive(0xca5dB9Bb25D09A9bF3b22360Be3763b5f2d13589);

    /// @dev The Uniswap v3 zap contract.
    IUniV3Zap internal zap;

    /// @dev "Mint" tokens to an account by transferring from the whale.
    /// @param _asset Asset to mint.
    /// @param _whale Account to mint from.
    /// @param _amount Amount of tokens to "mint".
    /// @param _to Destination for the tokens.
    function mint(
        address _asset,
        address _whale,
        uint256 _amount,
        address _to
    ) internal {
        vm.startPrank(_whale);
        IERC20(_asset).transfer(_to, _amount);
        vm.stopPrank();
    }

    /// @dev Deploy a strategy pointing to the sDAI hyperdrive instance and
    ///      create a vault around it.
    function setUp() public virtual override {
        super.setUp();

        // Instantiate the zap contract.
        zap = IUniV3Zap(new UniV3Zap("Test Zap", SWAP_ROUTER, IWETH(WETH)));

        // SDAI Hyperdrive mainnet address.
        hyperdrive = SDAI_HYPERDRIVE;

        // Set the correct asset.
        asset = IERC20(USDC);

        vm.startPrank(deployer);

        // Deploy and configure the strategy.
        AS_BASE = false;
        strategy = IPermissionedStrategy(
            address(
                new EverlongStrategy(
                    address(asset),
                    "USDC sDAIHyperdrive Strategy",
                    address(hyperdrive),
                    IEverlongStrategy.ZapConfig({
                        asBase: AS_BASE,
                        zap: address(zap),
                        shouldWrap: true,
                        isRebasing: false,
                        inputExpiry: 1 minutes,
                        outputExpiry: 1 minutes,
                        inputPath: abi.encodePacked(
                            USDC,
                            LOW_FEE_TIER,
                            DAI,
                            LOW_FEE_TIER,
                            SDAI
                        ),
                        outputPath: abi.encodePacked(
                            SDAI,
                            LOW_FEE_TIER,
                            DAI,
                            LOW_FEE_TIER,
                            USDC
                        )
                    })
                )
            )
        );
        strategy.setPerformanceFeeRecipient(governance);
        strategy.setKeeper(address(keeperContract));
        strategy.setPendingManagement(management);
        strategy.setEmergencyAdmin(emergencyAdmin);

        // Issue the deployer a bunch of stETH... this makes it easy to dish
        // out to other users later.
        // uint256 deployerETH = 1_000e18;
        // deal(deployer, deployerETH);
        // ILido(address(asset)).submit{ value: deployerETH }(deployer);

        vm.stopPrank();

        // As the `management` address:
        //   1. Accept the `management` role for the strategy.
        //   2. Set the `profitMaxUnlockTime` to zero.
        vm.startPrank(management);
        strategy.acceptManagement();
        strategy.setProfitMaxUnlockTime(STRATEGY_PROFIT_MAX_UNLOCK_TIME);
        strategy.setPerformanceFee(0);
        vm.stopPrank();

        // As the `governance` address:
        //   1. Deploy the Vault using the RoleManager.
        //   2. Add the EverlongStrategy to the vault.
        //   3. Update the max debt for the strategy to be the maximum uint256.
        //   4. Configure the vault to `auto_allocate` which will automatically
        //      update the strategy's debt on deposit.
        vm.startPrank(governance);
        vault = IVault(
            roleManager.newVault(
                address(asset),
                0,
                EVERLONG_NAME,
                EVERLONG_SYMBOL
            )
        );
        vault.add_strategy(address(strategy));
        vault.update_max_debt_for_strategy(
            address(strategy),
            type(uint256).max
        );
        roleManager.setPositionHolder(
            roleManager.KEEPER(),
            address(keeperContract)
        );
        vm.stopPrank();

        // As the `management` address, configure the DebtAllocator to not
        // wait to update a strategy's debt and set the minimum change before
        // updating to just above hyperdrive's minimum transaction amount.
        vm.startPrank(management);
        // Set the vault's duration for unlocking profit.
        vault.setProfitMaxUnlockTime(VAULT_PROFIT_MAX_UNLOCK_TIME);
        // Enable deposits to the strategy from the vault.
        strategy.setDepositor(address(vault), true);
        // Give the `EverlongStrategyKeeper` role to the keeper address.
        debtAllocator.setKeeper(address(keeperContract), true);
        // Set minimum wait time for updating strategy debt.
        debtAllocator.setMinimumWait(0);
        // Set minimum change in debt for triggering an update.
        debtAllocator.setMinimumChange(
            address(vault),
            MINIMUM_TRANSACTION_AMOUNT + 1
        );
        debtAllocator.setStrategyDebtRatio(
            address(vault),
            address(strategy),
            MAX_BPS - TARGET_IDLE_LIQUIDITY_BASIS_POINTS,
            MAX_BPS - MIN_IDLE_LIQUIDITY_BASIS_POINTS
        );
        vm.stopPrank();
    }

    /// @dev Ensure the deposit/redeem functions work as expected for the happy
    ///      path.
    function test_simple_deposit_redeem() external {
        // Alice deposit into the vault.
        uint256 depositAmount = 100e8;
        mint(USDC, USDC_WHALE, depositAmount, alice);

        vm.startPrank(alice);
        asset.approve(address(vault), depositAmount);
        uint256 aliceShares = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        rebalance();

        // Alice should have non-zero share amounts.
        assertGt(aliceShares, 0);

        vm.startPrank(alice);
        uint256 proceeds = vault.redeem(aliceShares, alice, alice);
        assertApproxEqRel(proceeds, depositAmount, 0.1e18);
    }
}
