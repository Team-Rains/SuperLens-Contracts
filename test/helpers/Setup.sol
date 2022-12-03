// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import "../../src/SuperLensFactory.sol";
import "./FoundrySuperfluidTester.sol";

abstract contract Setup is FoundrySuperfluidTester {
    using CFAv1Library for CFAv1Library.InitData;

    SuperLensFactory Factory;
    address streamManagerImplementation;
    address socialTokenImplementation;
    address stakingContractImplementation;

    address constant deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    constructor() FoundrySuperfluidTester(3) {}

    function setUp() public override {
        // Deploy new stream manager implementation contract.
        streamManagerImplementation = address(new StreamManager());

        // Deploy new social token implementation contract.
        socialTokenImplementation = address(new SocialToken());

        // Deploy new staking contract implementation contract.
        stakingContractImplementation = address(new StakingContract());

        // Deploy factory contract.
        Factory = new SuperLensFactory({
            _host: address(sf.host),
            _cfa: address(sf.cfa),
            _ida: address(sf.ida),
            _cfaV1Forwarder: address(sf.cfaV1Forwarder),
            _superTokenFactory: address(sf.superTokenFactory),
            _streamManagerImplementation: streamManagerImplementation,
            _socialTokenImplementation: socialTokenImplementation,
            _stakingContractImplementation: stakingContractImplementation
        });

        // Creates a mock token and a supertoken and fills the mock wallets.
        FoundrySuperfluidTester.setUp();

        // Filling the deployer's wallet with mock tokens and supertokens.
        fillWallet(deployer);
    }

    function _createSet()
        internal
        returns (
            address _streamManager,
            address _socialToken,
            address _stakingContract
        )
    {
        vm.startPrank(admin);

        // Initialising a creator set.
        Factory.initCreatorSet(
            address(superToken),
            _convertToRate(1e10),
            "TESTING",
            "$TEST",
            1e24
        );

        (_streamManager, _socialToken, _stakingContract) = Factory.creatorSet(
            admin
        );
        vm.stopPrank();
    }

    function _convertToRate(uint256 _rate)
        internal
        pure
        returns (int96 _flowRate)
    {
        _flowRate = int96(int256(_rate / 2592000));
    }
}