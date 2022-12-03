// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import "./helpers/Setup.sol";


contract SetupTest is Test, Setup {

  // test createSet
  function testCreateSet () public {
    (address newStreamManager, address newSocialToken, address newStakingContract) = _createSet();

    assertTrue(newStreamManager != address(0), "new stream manager is null");
    assertTrue(newSocialToken != address(0), "new social token is null");
    assertTrue(newStakingContract != address(0), "new staking contract is null");
  }
}