// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

// import {ISuperfluid, ISuperToken} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
// import {IcfaV1Forwarder} from "../src/interfaces/IcfaV1Forwarder.sol";
import "../src/SuperLensFactory.sol";
import "../src/StreamManager.sol";
import "../src/SocialToken.sol";
import "../src/StakingContract.sol";
import "forge-std/Script.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address forwarder = vm.envAddress("CFAV1_FORWARDER_ADDRESS");
        address host = vm.envAddress("SF_HOST_ADDRESS");
        address cfa = vm.envAddress("CFA_ADDRESS");
        address ida = vm.envAddress("IDA_ADDRESS");
        address superTokenFactory = vm.envAddress("SUPERTOKEN_FACTORY");
        vm.startBroadcast(deployerPK);

        // Deploy new stream manager implementation contract.
        address streamManagerImplementation = address(new StreamManager());

        // Deploy new social token implementation contract.
        address socialTokenImplementation = address(new SocialToken());

        // Deploy new staking contract implementation contract.
        address stakingContractImplementation = address(new StakingContract());

        // Deploy factory contract.
        SuperLensFactory Factory = new SuperLensFactory({
            _host: host,
            _cfa: cfa,
            _ida: ida,
            _cfaV1Forwarder: forwarder,
            _superTokenFactory: superTokenFactory,
            _streamManagerImplementation: streamManagerImplementation,
            _socialTokenImplementation: socialTokenImplementation,
            _stakingContractImplementation: stakingContractImplementation
        });

        vm.stopBroadcast();
    }
}