// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {SuperAppBase} from "protocol-monorepo/packages/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {CFAv1Library} from "protocol-monorepo/packages/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {IcfaV1Forwarder, ISuperToken, ISuperfluid, IConstantFlowAgreementV1} from "./interfaces/IcfaV1Forwarder.sol";
import {IERC721Mod} from "./interfaces/IERC721Mod.sol";
import {IStreamManager} from "./interfaces/IStreamManager.sol";
import {SocialToken} from "./SocialToken.sol";
import "forge-std/console.sol";

contract StreamManager is
    IStreamManager,
    IERC721Mod,
    SuperAppBase,
    Initializable
{
    using CFAv1Library for CFAv1Library.InitData;

    address public CREATOR;

    ISuperToken public PAYMENT_TOKEN;

    SocialToken public SOCIAL_TOKEN;

    address public STAKING_CONTRACT;

    IcfaV1Forwarder public FORWARDER;

    CFAv1Library.InitData public CFA_V1;

    address public HOST;

    int96 paymentFlowrate;

    function initialize(
        address _creator,
        address _paymentToken,
        address payable _socialToken,
        address _stakingContract,
        address _forwarder,
        address _host,
        address _cfa,
        int96 _paymentFlowrate
    ) external initializer {
        if (
            _socialToken == address(0) ||
            _stakingContract == address(0) ||
            _creator == address(0)
        ) revert ZeroAddress();

        FORWARDER = IcfaV1Forwarder(_forwarder);
        SOCIAL_TOKEN = SocialToken(_socialToken);
        PAYMENT_TOKEN = ISuperToken(_paymentToken);
        STAKING_CONTRACT = _stakingContract;
        HOST = _host;
        CREATOR = _creator;
        paymentFlowrate = _paymentFlowrate;
        CFA_V1 = CFAv1Library.InitData({
            host: ISuperfluid(_host),
            cfa: IConstantFlowAgreementV1(_cfa)
        });
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

    // NOTE: If the content creator gives 0 as `_newPaymentFlowrate` it means anyone can
    // view the gated publications.
    function setPaymentFlowrate(int96 _newPaymentFlowrate) external {
        if (msg.sender != CREATOR) revert NotCreator(msg.sender, CREATOR);
        if (_newPaymentFlowrate < 0)
            revert InvalidPaymentFlowrate(_newPaymentFlowrate);

        int96 oldPaymentFlowrate = paymentFlowrate;
        paymentFlowrate = _newPaymentFlowrate;

        emit PaymentFlowrateChanged(_newPaymentFlowrate, oldPaymentFlowrate);
    }

    function afterAgreementCreated(
        ISuperToken _superToken,
        address, /*_agreementClass*/
        bytes32, /*_agreementId*/
        bytes calldata _agreementData,
        bytes calldata, /*_cbdata*/
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
            paymentToken, // token
            subscriber, // sender
            address(this) // receiver
        );

        if (incomingFlowrate < paymentFlowrate)
            revert WrongAmount(paymentFlowrate, incomingFlowrate);

        // Start a social token stream back to the subscriber.
        _newCtx = CFA_V1.createFlowByOperatorWithCtx(
            _newCtx,
            address(SOCIAL_TOKEN),
            subscriber,
            ISuperToken(address(SOCIAL_TOKEN)),
            incomingFlowrate
        );

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
        int96 creatorFlowrateDelta = incomingFlowrate -
            stakingContractFlowrateDelta;

        // Increase the flowrate to staking contract (10% of the original flowrate).
        // Note: If the subscriber is the first one, you need to open a flow.
        if (stakingContractRate != int96(0)) {
            _newCtx = CFA_V1.updateFlowWithCtx(
                _newCtx,
                STAKING_CONTRACT,
                paymentToken,
                stakingContractRate + stakingContractFlowrateDelta
            );
        } else {
            _newCtx = CFA_V1.createFlowWithCtx(
                _newCtx,
                STAKING_CONTRACT,
                paymentToken,
                stakingContractFlowrateDelta
            );
        }

        // Increase the flowrate to creator (90% of original flowrate).
        // Note: If the subscriber is the first one, you need to open a flow.
        if (creatorRate != int96(0)) {
            _newCtx = CFA_V1.updateFlowWithCtx(
                _newCtx,
                CREATOR,
                paymentToken,
                creatorRate + creatorFlowrateDelta
            );
        } else {
            _newCtx = CFA_V1.createFlowWithCtx(
                _newCtx,
                CREATOR,
                paymentToken,
                creatorRate + creatorFlowrateDelta
            );
        }
    }

    function afterAgreementUpdated(
        ISuperToken, /*_superToken*/
        address, /*_agreementClass*/
        bytes32, /*_agreementId*/
        bytes calldata, /*_agreementData*/
        bytes calldata, /*_cbdata*/
        bytes calldata /*_ctx*/
    )
        external
        pure
        override
        returns (
            bytes memory /*_newCtx*/
        )
    {
        revert UpdatesNotPermitted();
    }

    function beforeAgreementTerminated(
        ISuperToken, /*_superToken*/
        address, /*_agreementClass*/
        bytes32, /*_agreementId*/
        bytes calldata _agreementData,
        bytes calldata /*_ctx*/
    ) external view override returns (bytes memory _cbdata) {
        if (msg.sender == HOST) {
            (address subscriber, ) = abi.decode(
                _agreementData,
                (address, address)
            );

            int96 oldIncomingFlowrate = FORWARDER.getFlowrate(
                ISuperToken(address(PAYMENT_TOKEN)),
                subscriber,
                address(this)
            );

            _cbdata = abi.encode(oldIncomingFlowrate);
        }
    }

    // TODO: Use try/catch block to handle critical errors.
    function afterAgreementTerminated(
        ISuperToken, /*_superToken*/
        address, /*_agreementClass*/
        bytes32, /*_agreementId*/
        bytes calldata _agreementData,
        bytes calldata _cbdata,
        bytes calldata _ctx
    ) external override returns (bytes memory _newCtx) {
        _newCtx = _ctx;

        if (msg.sender == HOST) {
            ISuperToken paymentToken = PAYMENT_TOKEN;
            IcfaV1Forwarder forwarder = FORWARDER;
            (address subscriber, ) = abi.decode(
                _agreementData,
                (address, address)
            );
            int96 oldIncomingFlowrate = abi.decode(_cbdata, (int96));
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

            int96 stakingContractFlowrateDelta = oldIncomingFlowrate /
                int96(10);
            int96 creatorFlowrateDelta = oldIncomingFlowrate -
                stakingContractFlowrateDelta;

            // Stop a social token stream back to the subscriber.
            _newCtx = CFA_V1.deleteFlowByOperatorWithCtx(
                _newCtx,
                address(SOCIAL_TOKEN),
                subscriber,
                ISuperToken(address(SOCIAL_TOKEN))
            );

            // Decrease the flowrate to staking contract (10% of the original flowrate).
            if (stakingContractRate == stakingContractFlowrateDelta) {
                _newCtx = CFA_V1.deleteFlowWithCtx(
                    _newCtx,
                    address(this),
                    STAKING_CONTRACT,
                    paymentToken
                );
            } else {
                _newCtx = CFA_V1.updateFlowWithCtx(
                    _newCtx,
                    STAKING_CONTRACT,
                    paymentToken,
                    stakingContractRate - stakingContractFlowrateDelta
                );
            }

            // Decrease the flowrate to staking contract (10% of the original flowrate).
            if (creatorRate == creatorFlowrateDelta) {
                _newCtx = CFA_V1.deleteFlowWithCtx(
                    _newCtx,
                    address(this),
                    CREATOR,
                    paymentToken
                );
            } else {
                _newCtx = CFA_V1.updateFlowWithCtx(
                    _newCtx,
                    CREATOR,
                    paymentToken,
                    creatorRate - creatorFlowrateDelta
                );
            }
        }
    }
}
