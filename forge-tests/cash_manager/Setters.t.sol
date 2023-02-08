// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";

contract TestSetters is BasicDeployment {
  function setUp() public {
    createDeploymentCash();

    vm.startPrank(managerAdmin);
    cashManager.grantRole(cashManager.MANAGER_ADMIN(), address(this));
    cashManager.grantRole(cashManager.SETTER_ADMIN(), address(this));
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                          Function Setters
  //////////////////////////////////////////////////////////////*/

  function test_unit_setMintExchangeRate_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.SETTER_ADMIN()));
    vm.prank(alice);
    cashManager.setMintExchangeRate(1e6, 0);
  }

  function test_unit_setMintExchangeRate_invalid_difference() public {
    uint256 newExchangeRate = 2e6; // Larger than 100bps diff from 1e6
    vm.warp(block.timestamp + 1 days);

    vm.expectEmit(true, true, true, true);
    emit MintExchangeRateCheckFailed(0, 1e6, newExchangeRate);

    cashManager.setMintExchangeRate(newExchangeRate, 0);

    // Check that the exchange rate was updated and paused
    assertEq(cashManager.epochToExchangeRate(0), 2e6);
    assertEq(cashManager.lastSetMintExchangeRate(), 1e6);
    assertEq(cashManager.paused(), true);
  }

  function test_unit_setMintExchangeRate_fail_epochNotElapsed() public {
    vm.expectRevert(ICashManager.EpochNotElapsed.selector);
    cashManager.setMintExchangeRate(1e6, 0);
  }

  function test_unit_setMintExchangeRate_fail_exchangeRateAlreadySet() public {
    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    // Set again
    vm.expectRevert(ICashManager.EpochExchangeRateAlreadySet.selector);
    cashManager.setMintExchangeRate(2e6, 0);
  }

  function test_unit_setMintExchangeRate_fail_zero_exchange_rate() public {
    vm.warp(block.timestamp + 1 days);
    vm.expectRevert(ICashManager.ZeroExchangeRate.selector);
    cashManager.setMintExchangeRate(0, 0);
  }

  function test_unit_setMintExchangeRate_valid_difference() public {
    uint256 newExchangeRate = 1010000; // 100bps diff from 1e6
    vm.warp(block.timestamp + 1 days);

    // Check event emits
    vm.expectEmit(true, true, true, true);
    emit MintExchangeRateSet(0, 1e6, newExchangeRate);

    cashManager.setMintExchangeRate(newExchangeRate, 0);

    // Check that exchange rate was updated and not paused
    assertEq(cashManager.epochToExchangeRate(0), newExchangeRate);
    assertEq(cashManager.paused(), false);
  }

  function test_unit_setMintExchangeRateDeltaLimit_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.SETTER_ADMIN()));
    vm.prank(alice);
    cashManager.setMintExchangeRate(1e6, 0);
  }

  function test_unit_setMintExchangeRateDeltaLimit() public {
    vm.expectEmit(true, true, true, true);
    emit ExchangeRateDeltaLimitSet(100, 50);
    cashManager.setMintExchangeRateDeltaLimit(50);
    assertEq(cashManager.exchangeRateDeltaLimit(), 50);
  }

  function test_unit_setMintFee_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setMintFee(100);
  }

  function test_unit_setMintFee_fail_tooLarge() public {
    vm.expectRevert(ICashManager.MintFeeTooLarge.selector);
    cashManager.setMintFee(10000);
  }

  function test_unit_setMintFee() public {
    vm.expectEmit(true, true, true, true);
    emit MintFeeSet(0, 50);
    cashManager.setMintFee(50);
    assertEq(cashManager.mintFee(), 50);
  }

  function test_unit_setMinimumDepositAmount_fail_tooSmall() public {
    vm.expectRevert(ICashManager.MinimumDepositAmountTooSmall.selector);
    cashManager.setMinimumDepositAmount(9999);
  }

  function test_unit_setMinimumDepositAmount_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setMinimumDepositAmount(2e6);
  }

  function test_unit_setMinimumDepositAmount() public {
    vm.expectEmit(true, true, true, true);
    emit MinimumDepositAmountSet(10_000, 2e6);
    cashManager.setMinimumDepositAmount(2e6);
    assertEq(cashManager.minimumDepositAmount(), 2e6);
  }

  function test_unit_setFeeReceipient_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setFeeRecipient(alice);
  }

  function test_unit_setFeeReceipient() public {
    vm.expectEmit(true, true, true, true);
    emit FeeRecipientSet(feeRecipient, alice);
    cashManager.setFeeRecipient(alice);
    assertEq(cashManager.feeRecipient(), alice);
  }

  function test_unit_setAssetRecipient_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setAssetRecipient(alice);
  }

  function test_unit_setAssetRecipient() public {
    vm.expectEmit(true, true, true, true);
    emit AssetRecipientSet(assetRecipient, alice);
    cashManager.setAssetRecipient(alice);
    assertEq(cashManager.assetRecipient(), alice);
  }

  function test_unit_setAssetSender_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setAssetSender(alice);
  }

  function test_unit_setAssetSender() public {
    vm.expectEmit(true, true, true, true);
    emit AssetSenderSet(assetSender, alice);
    cashManager.setAssetSender(alice);
    assertEq(cashManager.assetSender(), alice);
  }

  function test_unit_setRedeemMinimum_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setRedeemMinimum(1e18);
  }

  function test_unit_setRedeemMinimum() public {
    vm.expectEmit(true, true, true, true);
    emit MinimumRedeemAmountSet(0, 1e18);
    cashManager.setRedeemMinimum(1e18);
    assertEq(cashManager.minimumRedeemAmount(), 1e18);
  }

  function test_unit_setMintLimit_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setMintLimit(5);
  }

  function test_unit_setMintLimit() public {
    vm.expectEmit(true, true, true, true);
    emit MintLimitSet(1000e6, 2000e6);
    cashManager.setMintLimit(2000e6);
    assertEq(cashManager.mintLimit(), 2000e6);
  }

  function test_unit_setKYCRegistry() public {
    vm.expectEmit(true, true, true, true);
    address oldRegistry = address(cashManager.kycRegistry());
    address newRegistry = address(0x456);
    emit KYCRegistrySet(oldRegistry, newRegistry);
    cashManager.setKYCRegistry(newRegistry);
    assertEq(address(cashManager.kycRegistry()), newRegistry);
  }

  function test_unit_setKYCRegistry_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setKYCRegistry(address(0x456));
  }

  function test_unit_setKYCRequirementGroup() public {
    vm.expectEmit(true, true, true, true);
    uint256 newKYCLevel = 55;
    emit KYCRequirementGroupSet(kycRequirementGroup, newKYCLevel);
    cashManager.setKYCRequirementGroup(newKYCLevel);
    assertEq(cashManager.kycRequirementGroup(), newKYCLevel);
  }

  function test_unit_setKYCRequirementGroup_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setKYCRequirementGroup(55);
  }

  function test_unit_setRedeemLimit_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setRedeemLimit(5);
  }

  function test_unit_setRedeemLimit() public {
    vm.expectEmit(true, true, true, true);
    emit RedeemLimitSet(1000e18, 2000e18);
    cashManager.setRedeemLimit(2000e18);
    assertEq(cashManager.redeemLimit(), 2000e18);
  }

  function test_unit_setEpochDuration_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.setEpochDuration(2 days);
  }

  function test_unit_setEpochDuration() public {
    vm.expectEmit(true, true, true, true);
    emit EpochDurationSet(1 days, 2 days);
    cashManager.setEpochDuration(2 days);
    assertEq(cashManager.epochDuration(), 2 days);
  }

  function test_unit_pause_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(address(this), cashManager.PAUSER_ADMIN()));
    cashManager.pause();
  }

  function test_unit_pause() public {
    vm.expectEmit(true, true, true, true);
    emit Paused(pauser);
    vm.prank(pauser);
    cashManager.pause();
    assertTrue(cashManager.paused());
  }

  function test_unit_unpause_fail_accessControl() public {
    // Pause before unpausing, otherwise it will revert
    vm.startPrank(pauser);
    cashManager.pause();

    // Pauser shouldn't be able to unpause - revert
    vm.expectRevert(_formatACRevert(pauser, cashManager.MANAGER_ADMIN()));
    cashManager.unpause();
    vm.stopPrank();
  }

  function test_unit_unpause() public {
    // Pause before unpausing, otherwise it will revert
    vm.prank(pauser);
    cashManager.pause();

    vm.expectEmit(true, true, true, true);
    emit Unpaused(address(this));

    cashManager.unpause();
    assertTrue(!cashManager.paused());
  }

  function test_unit_overrideExchangeRate_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    vm.prank(alice);
    cashManager.overrideExchangeRate(2e6, 0, 0);
  }

  function test_unit_overrideExchangeRate_fail_invalidEpoch() public {
    vm.expectRevert(ICashManager.MustServicePastEpoch.selector);
    cashManager.overrideExchangeRate(2e6, 0, 0);
  }

  function test_unit_overrideExchangeRate_alter_last_set() public {
    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    vm.expectEmit(true, true, true, true);
    emit MintExchangeRateOverridden(0, 1e6, 2e6, 15e5);
    cashManager.overrideExchangeRate(2e6, 0, 15e5);

    assertEq(cashManager.lastSetMintExchangeRate(), 15e5);
    assertEq(cashManager.epochToExchangeRate(0), 2e6);
  }

  function test_unit_overrideExchangeRate_no_alter_last_set() public {
    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    vm.expectEmit(true, true, true, true);
    emit MintExchangeRateOverridden(0, 1e6, 2e6, 1e6);
    cashManager.overrideExchangeRate(2e6, 0, 0);

    assertEq(cashManager.lastSetMintExchangeRate(), 1e6);
    assertEq(cashManager.epochToExchangeRate(0), 2e6);
  }

  /*//////////////////////////////////////////////////////////////
                            Constructor Setters
  //////////////////////////////////////////////////////////////*/

  function test_unit_constructor_fail_collateral() public {
    vm.expectRevert(ICashManager.CollateralZeroAddress.selector);
    deployCashManager(
      address(0),
      address(cashProxied),
      managerAdmin,
      pauser,
      assetRecipient,
      assetSender,
      feeRecipient,
      1000e18,
      1000e18,
      1 days,
      address(registry),
      kycRequirementGroup
    );
  }

  function test_unit_constructor_fail_cashToken() public {
    vm.expectRevert(ICashManager.CashZeroAddress.selector);
    deployCashManager(
      address(usdc),
      address(0),
      managerAdmin,
      pauser,
      assetRecipient,
      assetSender,
      feeRecipient,
      1000e18,
      1000e18,
      1 days,
      address(registry),
      kycRequirementGroup
    );
  }

  function test_unit_constructor_fail_assetRecipient() public {
    vm.expectRevert(ICashManager.AssetRecipientZeroAddress.selector);
    deployCashManager(
      address(usdc),
      address(cashProxied),
      managerAdmin,
      pauser,
      address(0),
      assetSender,
      feeRecipient,
      1000e18,
      1000e18,
      1 days,
      address(registry),
      kycRequirementGroup
    );
  }

  function test_unit_constructor_fail_assetSender() public {
    vm.expectRevert(ICashManager.AssetSenderZeroAddress.selector);
    deployCashManager(
      address(usdc),
      address(cashProxied),
      managerAdmin,
      pauser,
      assetRecipient,
      address(0),
      feeRecipient,
      1000e18,
      1000e18,
      1 days,
      address(registry),
      2
    );
  }

  function test_unit_constructor_fail_feeRecipient() public {
    vm.expectRevert(ICashManager.FeeRecipientZeroAddress.selector);
    deployCashManager(
      address(usdc),
      address(cashProxied),
      managerAdmin,
      pauser,
      assetRecipient,
      assetSender,
      address(0),
      1000e18,
      1000e18,
      1 days,
      address(registry),
      kycRequirementGroup
    );
  }

  function test_unit_constructor_fail_registryAddress() public {
    vm.expectRevert(IKYCRegistryClient.RegistryZeroAddress.selector);
    deployCashManager(
      address(usdc),
      address(cashProxied),
      managerAdmin,
      pauser,
      assetRecipient,
      assetSender,
      feeRecipient,
      1000e18,
      1000e18,
      1 days,
      address(0), // Registry
      kycRequirementGroup
    );
  }

  // Remove current address from cash manager admin
  function _beforeAccessControl() internal {
    cashManager.revokeRole(cashManager.MANAGER_ADMIN(), address(this));
  }

  function test_unit_constructor_epochAlignment() public {
    assertEq(cashManager.currentEpochStartTimestamp() % 1 days, 0);
  }

  function test_unit_constructor_decimalsMultiplier_usdc() public {
    assertEq(cashManager.decimalsMultiplier(), 1e12);
  }

  function test_unit_constructor_accessControl_defaultAdmin() public {
    assertEq(
      cashManager.getRoleMember(cashManager.DEFAULT_ADMIN_ROLE(), 0),
      managerAdmin
    );
    assertEq(
      cashManager.getRoleMemberCount(cashManager.DEFAULT_ADMIN_ROLE()),
      1
    );
  }

  function test_unit_constructor_accessControl_managerAdmin() public {
    // Remove current address from cash manager admin
    vm.startPrank(managerAdmin);
    cashManager.revokeRole(cashManager.MANAGER_ADMIN(), address(this));
    vm.stopPrank();

    assertEq(
      cashManager.getRoleAdmin(cashManager.MANAGER_ADMIN()),
      cashManager.DEFAULT_ADMIN_ROLE()
    );
    assertEq(
      cashManager.getRoleMember(cashManager.MANAGER_ADMIN(), 0),
      managerAdmin
    );
    assertEq(cashManager.getRoleMemberCount(cashManager.MANAGER_ADMIN()), 1);
  }

  function test_unit_constructor_accessControl_pauserAdmin() public {
    assertEq(cashManager.getRoleMember(cashManager.PAUSER_ADMIN(), 0), pauser);
    assertEq(cashManager.getRoleMemberCount(cashManager.PAUSER_ADMIN()), 1);
    assertEq(
      cashManager.getRoleAdmin(cashManager.PAUSER_ADMIN()),
      cashManager.MANAGER_ADMIN()
    );
  }

  function test_unit_access_control_set_pending_redemption() public {
    // Have alice attempt to artifically set a redemption balance
    vm.startPrank(alice);
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    cashManager.setPendingRedemptionBalance(alice, 0, 100);
    vm.stopPrank();
  }

  function test_unit_bad_epoch_set_pending_redemption() public {
    // Have manager attempt to set a redemption balance in future
    vm.startPrank(managerAdmin);
    vm.expectRevert(ICashManager.CannotServiceFutureEpoch.selector);
    cashManager.setPendingRedemptionBalance(alice, 1, 1);
    vm.stopPrank();
  }

  function test_unit_access_control_set_pending_mint() public {
    // Have alice attempt to artifically set a mint balance
    vm.startPrank(alice);
    vm.expectRevert(_formatACRevert(alice, cashManager.MANAGER_ADMIN()));
    cashManager.setPendingMintBalance(alice, 0, 0, 100);
    vm.stopPrank();
  }

  function test_unit_bad_epoch_set_pending_mint() public {
    // Have manager attempt to set a mint balance in future
    vm.startPrank(managerAdmin);
    vm.expectRevert(ICashManager.CannotServiceFutureEpoch.selector);
    cashManager.setPendingMintBalance(alice, 1, 0, 1);
    vm.stopPrank();
  }

  function test_unit_bad_prev_balance_set_pending_mint() public {
    // Have manager attempt to set a balance with an incorrect previous
    // balance
    vm.startPrank(managerAdmin);
    // set value to 1,
    cashManager.setPendingMintBalance(alice, 0, 0, 1);
    vm.expectRevert(ICashManager.UnexpectedMintBalance.selector);
    // Failes because old value is 1, not 0
    cashManager.setPendingMintBalance(alice, 0, 0, 10);
    vm.stopPrank();
  }
}
