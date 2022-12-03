// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {SuperTokenBase} from "lib/custom-supertokens/contracts/base/SuperTokenBase.sol";
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {IcfaV1Forwarder, ISuperToken, ISuperfluid} from "./interfaces/IcfaV1Forwarder.sol";
import "lib/custom-supertokens/contracts/base/UUPSProxy.sol";

/// @title Minimal Pure Super Token
/// @author jtriley.eth
/// @notice Pre-minted supply. This is includes no custom logic. Used in `PureSuperTokenDeployer`
contract SocialToken is SuperTokenBase {
    /// @dev Upgrades the super token with the factory, then initializes.
    /// @param _factory super token factory for initialization
    /// @param _name super token name
    /// @param _symbol super token symbol
    /// @param _receiver Receiver of pre-mint
    /// @param _initialSupply Initial token supply to pre-mint
    function initialize(
        address _factory,
        string memory _name,
        string memory _symbol,
        address _receiver,
        uint256 _initialSupply,
        address _streamManager,
        address _forwarder
    ) external {
        _initialize(_factory, _name, _symbol);

        _mint(_receiver, _initialSupply, "");

        // control to the stream manager for using createFlowByOperator permission
        IcfaV1Forwarder forwarder = IcfaV1Forwarder(_forwarder);
        forwarder.grantPermissions(ISuperToken(address(this)), _streamManager);
    }
}
// First this contract is deployed, then Stream manager, then initialize the social token.
