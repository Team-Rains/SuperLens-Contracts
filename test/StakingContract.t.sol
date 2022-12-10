// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import "./helpers/Setup.sol";
import "forge-std/console.sol";

contract StakingContractTest is Test, Setup {
    using CFAv1Library for CFAv1Library.InitData;
    using IDAv1Library for IDAv1Library.InitData;

    function testStakeSingle() public {
        (
            address streamManager,
            address socialToken,
            address stakingContract
        ) = _createSet();
        // IcfaV1Forwarder forwarder = IcfaV1Forwarder(address(sf.cfaV1Forwarder));
        CFAv1Library.InitData storage cfaLib = sf.cfaLib;
        IDAv1Library.InitData storage idaLib = sf.idaLib;
        int96 incomingFlowrate = _convertToRate(1e10);

        vm.startPrank(alice);
        cfaLib.createFlow(
            streamManager,
            ISuperToken(address(superToken)),
            incomingFlowrate
        );

        // Skip a month.
        skip(3600 * 24 * 30);

        uint256 expectedBalance = uint256(
            uint96(_convertToRate(1e10)) * (3600 * 24 * 30)
        );

        assertEq(
            ISuperToken(socialToken).balanceOf(alice),
            expectedBalance,
            "Social token balance is wrong"
        );

        ISuperToken(socialToken).increaseAllowance(
            stakingContract,
            type(uint256).max
        );

        StakingContract(stakingContract).stake(expectedBalance);

        idaLib.approveSubscription(
            ISuperToken(address(superToken)),
            stakingContract,
            0
        );

        assertEq(
            StakingContract(stakingContract).stakedBalance(alice),
            expectedBalance,
            "Staked balance is not equal"
        );

        (
            bool exist,
            bool approved,
            uint128 units,
            /* uint256 pendingDistribution */
        ) = idaLib.getSubscription(
                ISuperToken(address(superToken)),
                stakingContract,
                0,
                alice
            );

        assertTrue(exist, "IDA subscription doesn't exist");
        assertTrue(approved, "IDA subscription not approved");
        assertEq(
            units,
            uint128(expectedBalance) / 1e9,
            "Subscription units are wrong"
        );
    }

    function testDistribute() public {
        (
            address streamManager,
            address socialToken,
            address stakingContract
        ) = _createSet();
        // IcfaV1Forwarder forwarder = IcfaV1Forwarder(address(sf.cfaV1Forwarder));
        CFAv1Library.InitData storage cfaLib = sf.cfaLib;
        IDAv1Library.InitData storage idaLib = sf.idaLib;
        int96 incomingFlowrate = _convertToRate(1e10);

        vm.startPrank(alice);
        cfaLib.createFlow(
            streamManager,
            ISuperToken(address(superToken)),
            incomingFlowrate
        );

        // Skip a month.
        skip(3600 * 24 * 30);

        ISuperToken(socialToken).increaseAllowance(
            stakingContract,
            type(uint256).max
        );

        uint256 expectedBalance = uint256(
            uint96(_convertToRate(1e10)) * (3600 * 24 * 30)
        );

        StakingContract(stakingContract).stake(expectedBalance);
        idaLib.approveSubscription(
            ISuperToken(address(superToken)),
            stakingContract,
            0
        );
        
        uint256 balanceBeforeStakingContract = ISuperToken(address(superToken))
            .balanceOf(stakingContract);
        uint256 balanceBeforeAlice = ISuperToken(address(superToken)).balanceOf(
            alice
        );
        // console.log("Balance of staking contract before: ", ISuperToken(address(superToken)).balanceOf(stakingContract));
        // console.log("Balance of alice before: ", ISuperToken(address(superToken)).balanceOf(alice));

        StakingContract(stakingContract).distribute();

        // console.log("Balance of staking contract after: ", ISuperToken(address(superToken)).balanceOf(stakingContract));
        // console.log("Balance of alice after: ", ISuperToken(address(superToken)).balanceOf(alice));

        assertEq(
            ISuperToken(address(superToken)).balanceOf(stakingContract),
            0,
            "Staking contract balance is wrong"
        );
        assertEq(
            ISuperToken(address(superToken)).balanceOf(alice),
            balanceBeforeStakingContract + balanceBeforeAlice,
            "Distribution amount wrong"
        );
    }
}
