// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";

contract TestEpoch is BasicDeployment {
  function setUp() public {
    createDeploymentCash();

    // Seed address with 1000000 USDC
    vm.prank(usdcWhale);
    usdc.transfer(address(this), INIT_BALANCE_USDC);

    // Grant admin role to this contract
    vm.startPrank(managerAdmin);
    cashManager.grantRole(cashManager.MANAGER_ADMIN(), address(this));
    vm.stopPrank();

    vm.prank(guardian);
    cashManager.grantRole(cashManager.SETTER_ADMIN(), address(this));
  }

  /*//////////////////////////////////////////////////////////////
                    Epoch Transition - Mints
  //////////////////////////////////////////////////////////////*/

  function test_unit_epochTransition_singleEpoch() public {
    uint256 epochTimestampBefore = cashManager.currentEpochStartTimestamp();

    // Increase timestamp
    vm.warp(block.timestamp + 1 days);

    // Set mint exchange rate to advance epochs
    cashManager.setMintExchangeRate(2e6, 0);

    // Check Epochs
    assertEq(cashManager.currentEpoch(), 1);
    // Start timestamp be aligned to a day
    assertEq(cashManager.currentEpochStartTimestamp() % 1 days, 0);
    assertEq(
      cashManager.currentEpochStartTimestamp() - epochTimestampBefore,
      1 days
    );
  }

  function test_unit_epochTransition_multiEpoch() public {
    uint256 epochTimestampBefore = cashManager.currentEpochStartTimestamp();

    // Increase timestamp
    vm.warp(block.timestamp + 2 days);

    // Set mint exchange rate to advance epochs
    cashManager.setMintExchangeRate(2e6, 1);

    // Check Epochs
    assertEq(cashManager.currentEpoch(), 2);
    // Start timestamp be aligned to a day
    assertEq(cashManager.currentEpochStartTimestamp() % 1 days, 0);
    assertEq(
      cashManager.currentEpochStartTimestamp() - epochTimestampBefore,
      2 days
    );
  }

  function test_fuzz_epochTransition(uint32 timestampIncrement) public {
    uint256 epochDuration = cashManager.epochDuration();
    uint256 epochTimestampBefore = cashManager.currentEpochStartTimestamp();

    // Increase Timestamp
    vm.warp(block.timestamp + timestampIncrement);

    // Set mint exchange rate to advance epochs
    if ((timestampIncrement / epochDuration) > 1) {
      cashManager.setMintExchangeRate(
        2e6,
        (timestampIncrement / epochDuration) - 1
      );
    }

    // Get timestamp diff between epochs
    uint256 epochTimestampDiff = cashManager.currentEpochStartTimestamp() -
      epochTimestampBefore;

    // If timestamp increment is less than epoch duration, epoch should not change
    if (epochTimestampDiff < epochDuration) {
      assertEq(cashManager.currentEpoch(), 0);
      assertEq(cashManager.currentEpochStartTimestamp(), epochTimestampBefore);
    } else {
      // Epoch transition math in CashManager should be equivalent to:
      // expectedEpochTimestmap = epochDuration * expectedEpochsPassed + prevEpochStartTimestamp
      // or, expectedEpochsPassed = (expectedEpochTimestmap - prevEpochStartTimestamp) / epochDuration
      uint256 expectedEpochTimestamp = block.timestamp -
        (block.timestamp % epochDuration);
      uint256 expectedEpoch = (expectedEpochTimestamp - epochTimestampBefore) /
        epochDuration;
      assertEq(cashManager.currentEpoch(), expectedEpoch);
      assertEq(
        cashManager.currentEpochStartTimestamp(),
        expectedEpochTimestamp
      );
      assertEq(epochTimestampDiff, expectedEpoch * epochDuration);
    }
  }
}
