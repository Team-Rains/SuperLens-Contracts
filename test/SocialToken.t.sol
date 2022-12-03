// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import "./helpers/Setup.sol";
import "../src/SuperLensFactory.sol";
import "../src/SocialToken.sol";

import {IcfaV1Forwarder, ISuperToken} from "../src//interfaces/IcfaV1Forwarder.sol";



contract SocialTokenTest is Test, Setup {
  // using CFAv1Library for CFAv1Library.InitData;

  function testSocialToken () public {

    // call _createSet()
    (address newStreamManager, address newSocialToken, address _newStakingContract) = _createSet();

    // need to check if permission for control, is given to the stream manager 
    // for using createFlowByOperator is given
    // flowOperator is the streamManager

    (uint8 permissions, int96 flowrateAllowance) = sf.cfaV1Forwarder.getFlowOperatorPermissions(
      ISuperToken(newSocialToken),
      newSocialToken,
      newStreamManager
    );
    console.log(permissions);
    assertTrue(permissions == 7, "Permission not granted");


    //console.log(newCtx);
  }



}