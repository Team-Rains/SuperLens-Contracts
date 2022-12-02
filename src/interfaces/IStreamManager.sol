// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {IcfaV1Forwarder, ISuperToken, ISuperfluid} from "./IcfaV1Forwarder.sol";

interface IStreamManager {
    error ZeroAddress();
    error UpdatesNotPermitted();
    error NotHost(address expectedHost, address actualCaller);
    error WrongPaymentToken(address expectedToken, address actualToken);
    error WrongAmount(int96 expectedAmount, int96 actualAmount);
    error InvalidPaymentFlowrate(int96 paymentFlowrate);
    error NotCreator(address caller, address creator);
    error FlowrateChangeFailed(int96 newFlowrate, int96 oldFlowrate);

    event PaymentFlowrateChanged(int96 newPaymentFlowrate, int96 oldPaymentFlowrate);
}