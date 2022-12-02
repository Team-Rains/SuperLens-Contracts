// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {SuperAppBase} from "protocol-monorepo/packages/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {PureSuperToken} from "lib/custom-supertokens/contracts/PureSuperToken.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {IcfaV1Forwarder, ISuperToken, ISuperfluid} from "./interfaces/IcfaV1Forwarder.sol";
import {IERC721Mod} from "./interfaces/IERC721Mod.sol";
import {IStreamManager} from "./interfaces/IStreamManager.sol";
import "forge-std/console.sol";

// TODO: Add `Ownable`.
// TODO: [Optional] multi tier system.
contract StreamManager is
    IStreamManager,
    IERC721Mod,
    SuperAppBase,
    Initializable
{
    address CREATOR;

    // TODO: Change this to `IStakingContract`.
    address STAKING_CONTRACT;

    ISuperToken PAYMENT_TOKEN;

    PureSuperToken SOCIAL_TOKEN;

    IcfaV1Forwarder FORWARDER;

    address HOST;

    int96 paymentFlowrate;

    function initialize(
        address _creator,
        address _paymentToken,
        address payable _socialToken,
        address _stakingContract,
        address _forwarder,
        address _host,
        int96 _paymentFlowrate
    ) external initializer {
        if (
            _socialToken == address(0) ||
            _stakingContract == address(0) ||
            _creator == address(0)
        ) revert ZeroAddress();

        FORWARDER = IcfaV1Forwarder(_forwarder);
        SOCIAL_TOKEN = PureSuperToken(_socialToken);
        PAYMENT_TOKEN = ISuperToken(_paymentToken);
        STAKING_CONTRACT = _stakingContract;
        HOST = _host;
        CREATOR = _creator;
        paymentFlowrate = _paymentFlowrate;
    }

    function balanceOf(address _subscriber)
        public
        view
        returns (uint256 _isSubscribed)
    {
        // This is akin to a boolean check. We are checking whether a subscriber is streaming
        // the minimum acceptable amount of payment token to the creator.
        _isSubscribed = (FORWARDER.getFlowrate(
            PAYMENT_TOKEN,
            _subscriber,
            address(this)
        ) >= paymentFlowrate)
            ? 1
            : 0;
    }

    function afterAgreementCreated(
        ISuperToken _superToken,
        address /*_agreementClass*/,
        bytes32 /*_agreementId*/,
        bytes calldata _agreementData,
        bytes calldata /*_cbdata*/,
        bytes calldata _ctx
    ) external override returns (bytes memory _newCtx) {
        _newCtx = _ctx;

        address host = HOST;
        if (msg.sender != host) revert NotHost(host, msg.sender);

        ISuperToken paymentToken = PAYMENT_TOKEN;
        IcfaV1Forwarder forwarder = FORWARDER;
        (address subscriber, ) = abi.decode(_agreementData, (address, address));

        // Check if the payment token is correct.
        if (_superToken != paymentToken)
            revert WrongPaymentToken(
                address(paymentToken),
                address(_superToken)
            );

        // Check if the amount going to be streamed is correct.
        int96 incomingFlowrate = forwarder.getFlowrate(
            ISuperToken(address(SOCIAL_TOKEN)), // token
            subscriber, // sender
            address(this) // receiver
        );

        if (incomingFlowrate < paymentFlowrate)
            revert WrongAmount(paymentFlowrate, incomingFlowrate);

        // Start a social token stream back to the subscriber.
        // TODO: Start a stream to subscriber of social tokens.
        // use `createFlowByOperator` in `IcfaV1Forwarder`.

        int96 stakingContractRate = forwarder.getFlowrate(
            paymentToken,
            address(this),
            STAKING_CONTRACT
        );
        int96 creatorRate = forwarder.getFlowrate(
            paymentToken,
            address(this),
            CREATOR
        );

        int96 stakingContractFlowrateDelta = incomingFlowrate / int96(10);
        int96 creatorFlowrateDelta = incomingFlowrate - stakingContractFlowrateDelta;

        // Increase the flowrate to staking contract (10% of the original flowrate).
        forwarder.setFlowrate(
            paymentToken,
            STAKING_CONTRACT,
            stakingContractRate + stakingContractFlowrateDelta
        );

        // Increase the flowrate to creator (90% of original flowrate).
        forwarder.setFlowrate(
            paymentToken,
            CREATOR,
            creatorRate + creatorFlowrateDelta
        );
    }
}
