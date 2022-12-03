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
    // ISuperToken immutable cashToken;
    // ISuperToken immutable stakingToken;
    ISuperToken public cashToken;
    ISuperToken public stakingToken;
    uint32 internal constant INDEX_ID = 0;

    using IDAv1Library for IDAv1Library.InitData;
    IDAv1Library.InitData internal _idaLib;

    // constructor(
    //     ISuperfluid host,
    //     IInstantDistributionAgreementV1 ida,
    //     ISuperToken cash,
    //     ISuperToken staking
    // ) {
    //     registry1820.setInterfaceImplementer(
    //         address(this),
    //         keccak256("ERC777TokensRecipient"),
    //         address(this)
    //     );
    //     cashToken = cash;
    //     stakingToken = staking;
    //     host.registerApp(
    //         SuperAppDefinitions.APP_LEVEL_FINAL |
    //             SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
    //             SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
    //             SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP |
    //             SuperAppDefinitions.AFTER_AGREEMENT_CREATED_NOOP |
    //             SuperAppDefinitions.AFTER_AGREEMENT_UPDATED_NOOP |
    //             SuperAppDefinitions.AFTER_AGREEMENT_TERMINATED_NOOP
    //     );
    //     _idaLib = IDAv1Library.InitData(host, ida);
    //     _idaLib.createIndex(cash, INDEX_ID);
    // }

    function initialize(
        ISuperfluid host,
        IInstantDistributionAgreementV1 ida,
        ISuperToken cash,
        ISuperToken staking
    ) external initializer {
        registry1820.setInterfaceImplementer(
            address(this),
            keccak256("ERC777TokensRecipient"),
            address(this)
        );
        
        console.log("1"); 

        cashToken = cash;
        stakingToken = staking;
        _idaLib = IDAv1Library.InitData(host, ida);
        console.log("2");
        // _idaLib.createIndex(cash, INDEX_ID);
        // console.log("3");
    }

    function tokensReceived(
        address, /*operator*/
        address from,
        address, /*to*/
        uint256 amount,
        bytes calldata, /*userData*/
        bytes calldata /*operatorData*/
    ) external {
        if (msg.sender == address(stakingToken)) {
            // If someone is sending the staking token (social token), the tokens are
            // staked on their behalf.
            _stake(from, amount);
        } else if (msg.sender == address(cashToken)) {
            // If anyone transfers the cash token, a distribution takes place.
            // The sender will lose a part or whole of his money.
            _idaLib.distribute(cashToken, INDEX_ID, amount);
        } else {
            revert();
        }
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
