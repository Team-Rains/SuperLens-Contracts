// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {IcfaV1Forwarder, ISuperToken, ISuperfluid} from "./IcfaV1Forwarder.sol";

interface IStreamManager {
    error ZeroAddress();
    error WrongPaymentToken(address expectedToken, address actualToken);
    error WrongAmount(int96 expectedAmount, int96 actualAmount);
    error NotHost(address expectedHost, address actualCaller);
}