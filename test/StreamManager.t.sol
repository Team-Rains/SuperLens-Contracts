// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import "./helpers/Setup.sol";
import "forge-std/console.sol";

contract StreamManagerTest is Test, Setup {
    using CFAv1Library for CFAv1Library.InitData;

    function testAfterAgreementCreatedSingle() public {
        (
            address streamManager,
            address socialToken,
            address stakingContract
        ) = _createSet();
        IcfaV1Forwarder forwarder = IcfaV1Forwarder(address(sf.cfaV1Forwarder));
        CFAv1Library.InitData storage cfaLib = sf.cfaLib;
        int96 incomingFlowrate = _convertToRate(1e10);

        vm.prank(alice);
        cfaLib.createFlow(streamManager, ISuperToken(address(superToken)), incomingFlowrate);

        assertEq(
            forwarder.getFlowrate(superToken, alice, streamManager),
            incomingFlowrate,
            "Subscriber's payment rate is incorrect"
        );
        assertEq(
            forwarder.getFlowrate(
                ISuperToken(socialToken),
                socialToken,
                alice
            ),
            incomingFlowrate
        );
        
        int96 stakingContractFlowrateDelta = incomingFlowrate / int96(10);
        int96 creatorContractFlowrateDelta = incomingFlowrate - stakingContractFlowrateDelta;

        assertEq(
            forwarder.getFlowrate(superToken, streamManager, stakingContract),
            stakingContractFlowrateDelta,
            "Staking contract's incoming rate is incorrect"
        );
        assertEq(
            forwarder.getFlowrate(superToken, streamManager, admin),
            creatorContractFlowrateDelta,
            "Creator's incoming rate is incorrect"
        );
    }

    function testAfterAgreementTerminatedSingle() public {
        (
            address streamManager,
            address socialToken,
            address stakingContract
        ) = _createSet();
        IcfaV1Forwarder forwarder = IcfaV1Forwarder(address(sf.cfaV1Forwarder));
        CFAv1Library.InitData storage cfaLib = sf.cfaLib;

        vm.startPrank(alice);
        cfaLib.createFlow(streamManager, ISuperToken(address(superToken)), _convertToRate(1e10));
        cfaLib.deleteFlow(alice, streamManager, ISuperToken(address(superToken)));
        vm.stopPrank();

        assertEq(
            forwarder.getFlowrate(superToken, alice, streamManager),
            0,
            "Subscriber's payment rate is incorrect"
        );
        assertEq(
            forwarder.getFlowrate(
                ISuperToken(socialToken),
                socialToken,
                alice
            ),
            0,
            "Subscriber's social token flow exists"
        );

        assertEq(
            forwarder.getFlowrate(superToken, streamManager, stakingContract),
            0,
            "Staking contract's flow exists"
        );
        assertEq(
            forwarder.getFlowrate(superToken, streamManager, admin),
            0,
            "Creator's flow exists"
        );
    }
}
