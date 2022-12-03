// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import {IConstantFlowAgreementV1} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {IInstantDistributionAgreementV1} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {ISuperToken, ISuperfluid, SuperAppBase, SuperAppDefinitions} from "protocol-monorepo/packages/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {IERC1820Registry} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC1820Registry.sol";
import {IInstantDistributionAgreementV1, IDAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/IDAv1Library.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "forge-std/console.sol";

contract StakingContract is SuperAppBase, Initializable {
    IERC1820Registry private registry1820 =
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    mapping(address => uint256) public stakedBalance;

    ISuperToken public cashToken;
    ISuperToken public stakingToken;
    uint32 internal constant INDEX_ID = 0;

    using IDAv1Library for IDAv1Library.InitData;
    IDAv1Library.InitData internal _idaLib;

    function initialize(
        ISuperfluid host,
        IInstantDistributionAgreementV1 ida,
        ISuperToken cash,
        ISuperToken staking
    ) external initializer {
        cashToken = cash;
        stakingToken = staking;
        _idaLib = IDAv1Library.InitData(host, ida);
        _idaLib.createIndex(cash, INDEX_ID);
    }

    function stake(uint256 _amount) external {
        _stake(msg.sender, _amount);

        // receive their SocialToken
        bool sent = stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    function unstake() external {
        _idaLib.distribute(
            cashToken,
            INDEX_ID,
            cashToken.balanceOf(address(this))
        );
        _idaLib.deleteSubscription(
            cashToken,
            address(this),
            INDEX_ID,
            msg.sender
        );
        bool sent = stakingToken.transferFrom(address(this), msg.sender, stakedBalance[msg.sender]);
    }

    // TODO: Figure out if we need to distribute cash tokens before the
    // withdrawal of the staking token.
    function withdraw() external {
        uint256 amount = stakedBalance[msg.sender];
        stakedBalance[msg.sender] = 0;
        stakingToken.transfer(msg.sender, amount);
    }

    function _stake(address staker, uint256 amount) internal {
        stakedBalance[staker] += amount;
        _idaLib.distribute(
            cashToken,
            INDEX_ID,
            cashToken.balanceOf(address(this))
        );
        _idaLib.updateSubscriptionUnits(
            cashToken,
            INDEX_ID,
            staker,
            uint128(stakedBalance[staker])
        );
    }
}
