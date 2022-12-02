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
contract StreamManager is IERC721Mod, SuperAppBase, Initializable {
    address CREATOR;

    // TODO: Change this to `IStakingContract`.
    address STAKING_CONTRACT;

    ISuperToken PAYMENT_TOKEN;

    PureSuperToken SOCIAL_TOKEN;

    IcfaV1Forwarder FORWARDER;

    address HOST;

    int96 paymentFlowRate;

    function initialize(
        address _creator,
        address _paymentToken,
        address _socialToken,
        address _stakingContract,
        address _forwarder,
        address _host,
        int96 _paymentFlowRate
    ) external initializer {
        if (
            _socialToken == address(0) ||
            _stakingContract == address(0) ||
            _creator == address(0)
        ) revert ZeroAddress();

        FORWARDER = _forwarder;
        SOCIAL_TOKEN = PureSuperToken(_socialToken);
        PAYMENT_TOKEN = ISuperToken(paymentToken);
        STAKING_CONTRACT = _stakingContract;
        HOST = _host;
        CREATOR = _creator;
    }

    function balanceOf(address _subscriber)
        public
        returns (uint256 _isSubscribed)
    {
        // This is akin to a boolean check. We are checking whether a subscriber is streaming
        // the minimum acceptable amount of payment token to the creator.
        _isSubscribed = (
            FORWARDER.getFlowrate(
                SOCIAL_TOKEN,
                _subscriber,
                address(this) >= paymentFlowRate
            )
        )
            ? 1
            : 0;
    }

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata _agreementData,
        bytes calldata _cbdata,
        bytes calldata _ctx
    ) external view returns (bytes memory _ctx) {
        _newCtx = _ctx;

        address host = HOST;
        if (msg.sender != host) revert NotHost(host, msg.sender);

        // - Check if the payment token is correct.
        // - Check if the amount going to be streamed is correct.
        // - Start a social token stream back to the subscriber.
        // - Increase the flowrate to staking contract (10% of the original flowrate).
        // - Increase the flowrate to creator (90% of original flowrate).

        ISuperToken paymentToken = PAYMENT_TOKEN;
        IcfaV1Forwarder forwarder = FORWARDER;
        PureSuperToken socialToken = SOCIAL_TOKEN;
        address stakingContract = STAKING_CONTRACT;
        address creator = CREATOR;

        (address subscriber, ) = abi.decode(_agreementData, (address, address));

        if (_superToken != paymentToken)
            revert WrongPaymentToken(
                address(paymentToken),
                address(_superToken)
            );

        int96 incomingFlowrate = forwarder.getFlowrate(
            socialToken, // token
            subscriber, // sender
            address(this) // receiver
        );

        if (incomingFlowrate < paymentFlowrate)
            revert WrongAmount(paymentFlowrate, incomingFlowrate);

        // TODO: Start a stream to subscriber of social tokens.
        // use `createFlowByOperator` in `IcfaV1Forwarder`.

        int96 stakingContractRate = forwarder.getFlowrate(
            paymentToken,
            address(this),
            stakingContract
        );
        int96 creatorRate = forwarder.getFlowrate(
            paymentToken,
            address(this),
            creator
        );

        forwarder.setFlowrate(
            paymentToken,
            stakingContract,
            stakingContractRate + (incomingFlowrate / int96(10))
        );
        forwarder.setFlowrate(
            paymentToken,
            creator,
            creatorRate + ((incomingFlowrate * 9) / 10)
        );
    }
}
