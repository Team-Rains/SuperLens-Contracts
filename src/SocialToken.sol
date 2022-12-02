// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {SuperTokenBase} from "lib/custom-supertokens/contracts/base/SuperTokenBase.sol";
import {IcfaV1Forwarder, ISuperToken, ISuperfluid} from "./interfaces/IcfaV1Forwarder.sol";

/// @title Minimal Pure Super Token
/// @author jtriley.eth
/// @notice Pre-minted supply. This is includes no custom logic. Used in `PureSuperTokenDeployer`
contract PureSuperToken is SuperTokenBase {

	/// @dev Upgrades the super token with the factory, then initializes.
  /// @param factory super token factory for initialization
	/// @param name super token name
	/// @param symbol super token symbol
	/// @param receiver Receiver of pre-mint
	/// @param initialSupply Initial token supply to pre-mint
    function initialize(
  
        address _factory,
        string memory _name,
        string memory _symbol,
        address _receiver,
        uint256 _initialSupply,
        address _streamManager,
        address _forwarder
    ) external {
      // control to the stream manager for using createFlowByOperator permission
        IcfaV1Forwarder FORWARDER = IcfaV1Forwarder(_forwarder);
        forwarder.grantPermissions(address.this, _streamManager);
        
        _initialize(_factory, _name, _symbol);

        
        _mint(receiver, initialSupply, "");
    }

    

}
// First this contract is deployed, then Stream manager, then initialize the social token
