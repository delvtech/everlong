// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import { BaseDeployScript } from "./shared/BaseDeployScript.sol";
import { IHyperdrive } from "hyperdrive/contracts/src/interfaces/IHyperdrive.sol";
import { IEverlongStrategy } from "../contracts/interfaces/IEverlongStrategy.sol";
import { EVERLONG_STRATEGY_KIND, EVERLONG_STRATEGY_KEEPER_KIND } from "../contracts/libraries/Constants.sol";
import { EverlongStrategy } from "../contracts/EverlongStrategy.sol";

contract DeployEverlongStrategy is BaseDeployScript {
    // Required Arguments
    uint256 internal DEPLOYER_PRIVATE_KEY;
    uint256 internal GOVERNANCE_PRIVATE_KEY;
    uint256 internal MANAGEMENT_PRIVATE_KEY;
    uint256 internal EMERGENCY_ADMIN_PRIVATE_KEY;
    string internal NAME;
    address internal HYPERDRIVE;

    // Optional Arguments
    bool internal AS_BASE;
    bool internal constant AS_BASE_DEFAULT = true;

    uint256 internal PROFIT_MAX_UNLOCK;
    uint256 internal PROFIT_MAX_UNLOCK_DEFAULT = 0;

    string internal KEEPER_CONTRACT_NAME;
    string internal KEEPER_CONTRACT_NAME_DEFAULT;

    // Artifact struct.
    StrategyArtifact internal output;

    function run() external {
        // Read required arguments.
        DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
        output.deployer = vm.addr(DEPLOYER_PRIVATE_KEY);
        GOVERNANCE_PRIVATE_KEY = vm.envUint("GOVERNANCE_PRIVATE_KEY");
        output.governance = vm.addr(GOVERNANCE_PRIVATE_KEY);
        MANAGEMENT_PRIVATE_KEY = vm.envUint("MANAGEMENT_PRIVATE_KEY");
        output.management = vm.addr(MANAGEMENT_PRIVATE_KEY);
        EMERGENCY_ADMIN_PRIVATE_KEY = vm.envUint("EMERGENCY_ADMIN_PRIVATE_KEY");
        output.emergencyAdmin = vm.addr(EMERGENCY_ADMIN_PRIVATE_KEY);
        NAME = vm.envString("NAME");
        output.name = NAME;
        HYPERDRIVE = vm.envAddress("HYPERDRIVE");
        output.hyperdrive = HYPERDRIVE;

        // Validate required arguments.
        require(
            output.governance != output.management,
            "ERROR: governance and management accounts must be different"
        );

        // Resolve optional argument defaults.
        KEEPER_CONTRACT_NAME_DEFAULT = hasDefaultKeeperContractArtifact(
            EVERLONG_STRATEGY_KEEPER_KIND
        )
            ? getDefaultKeeperContractArtifact(EVERLONG_STRATEGY_KEEPER_KIND)
                .name
            : "";

        // Read optional arguments.
        AS_BASE = vm.envOr("AS_BASE", AS_BASE_DEFAULT);
        PROFIT_MAX_UNLOCK = vm.envOr(
            "PROFIT_MAX_UNLOCK",
            PROFIT_MAX_UNLOCK_DEFAULT
        );
        KEEPER_CONTRACT_NAME = vm.envOr(
            "KEEPER_CONTRACT_NAME",
            KEEPER_CONTRACT_NAME_DEFAULT
        );
        output.keeperContractName = KEEPER_CONTRACT_NAME;

        // Validate optional arguments.
        require(
            vm.isFile(getKeeperContractArtifactPath(output.keeperContractName)),
            "ERROR: KEEPER_CONTRACT_NAME cannot be found in artifacts"
        );
        address keeperContractAddress = getKeeperContractArtifact(
            output.keeperContractName
        ).keeperContract;

        // Resolve the asset address.
        address asset = AS_BASE
            ? IHyperdrive(output.hyperdrive).baseToken()
            : IHyperdrive(output.hyperdrive).vaultSharesToken();

        // Save the strategy's kind to output.
        output.kind = EVERLONG_STRATEGY_KIND;

        // As the `deployer` account:
        //   1. Deploy the strategy contract.
        //   2. Set the strategy's performanceFeeRecipient.
        //   3. Set the strategy's keeper to the KeeperContract.
        //   4. Set the strategy's management address to `management`.
        //   5. Set the strategy's emergencyAdmin to `emergencyAdmin`.
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);
        output.strategy = address(
            new EverlongStrategy(asset, output.name, output.hyperdrive, AS_BASE)
        );
        IEverlongStrategy(output.strategy).setPerformanceFeeRecipient(
            output.governance
        );
        IEverlongStrategy(output.strategy).setKeeper(keeperContractAddress);
        IEverlongStrategy(output.strategy).setPendingManagement(
            output.management
        );
        IEverlongStrategy(output.strategy).setEmergencyAdmin(
            output.emergencyAdmin
        );
        vm.stopBroadcast();

        // As the `management` account:
        //   1. Accept the management role for the strategy.
        //   2. Set the profitMaxUnlockTime.
        //   3. Set the performanceFee to zero.
        vm.startBroadcast(MANAGEMENT_PRIVATE_KEY);
        IEverlongStrategy(output.strategy).acceptManagement();
        IEverlongStrategy(output.strategy).setProfitMaxUnlockTime(
            PROFIT_MAX_UNLOCK
        );
        IEverlongStrategy(output.strategy).setPerformanceFee(0);
        vm.stopBroadcast();

        // Write output in toml format to a file.
        writeStrategyArtifact(output);
    }
}
