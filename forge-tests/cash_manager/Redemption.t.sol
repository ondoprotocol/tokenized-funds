// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";
import "forge-std/console2.sol";

abstract contract TestCashRedemption is BasicDeployment {
  address[] toWithdraw;
  address[] toRefund;

  function test_unit_redeem_fail_zero() public {
    vm.startPrank(managerAdmin);
    cashManager.setRedeemMinimum(10);
    vm.stopPrank();
    vm.startPrank(alice);
    vm.expectRevert(ICashManager.WithdrawRequestAmountTooSmall.selector);
    cashManager.requestRedemption(5);
    vm.stopPrank();
  }

  function test_unit_redeem_fail_mintLimit() public {
    _seed(5000e18, 0, 0);
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 3000e18);
    vm.expectRevert(ICashManager.RedeemExceedsRateLimit.selector);
    cashManager.requestRedemption(3000e18);
    vm.stopPrank();
  }

  function test_unit_redeem_fail_Allowance() public {
    _seed(100e18, 0, 0);
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    vm.expectRevert(bytes("ERC20: insufficient allowance"));
    cashManager.requestRedemption(200e18);
  }

  function test_unit_requestRedeem_failKYC() public {
    _seed(100e18, 0, 0);
    _removeAddressFromKYC(kycRequirementGroup, alice);
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    vm.expectRevert(ICashManager.KYCCheckFailed.selector);
    cashManager.requestRedemption(100e18);
  }

  function test_unit_redeem_fail_serviceCurrentEpoch() public {
    _seed(100e18, 0, 0);
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Approve cashMinter contract from assetSender account
    _seedSenderWithCollateral(125e6);

    // Expect Revert
    toWithdraw.push(alice);
    vm.prank(managerAdmin);
    vm.expectRevert(ICashManager.MustServicePastEpoch.selector);
    cashManager.completeRedemptions(toWithdraw, toRefund, 125e6, 0, 5e6);
  }

  function test_unit_redeem_singleUser() public {
    _seed(100e18, 0, 0);
    // Have alice request to withdraw 100 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    vm.expectEmit(true, true, true, true);
    emit RedemptionRequested(alice, 100e18, 0);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(125e3, 0);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(125e6);

    toWithdraw.push(alice);
    vm.prank(managerAdmin);
    vm.expectEmit(true, true, true, true);
    emit RedemptionCompleted(alice, 100e18, 120e6, 0);
    cashManager.completeRedemptions(toWithdraw, toRefund, 125e6, 0, 5e6);
    assertEq(usdc.balanceOf(feeRecipient), 5e6);
    assertEq(usdc.balanceOf(alice), 120e6);
    assertEq(
      cashManager.getBurnedQuantity(cashManager.currentEpoch() - 1, alice),
      0
    );
  }

  function test_unit_redeem_failRedeemTooSmall() public {
    uint256 LARGE_REDEMPTION = 1000000e18;
    _seed(100e18, LARGE_REDEMPTION, 0);
    vm.prank(managerAdmin);
    cashManager.setRedeemLimit(LARGE_REDEMPTION * 10);
    // Have alice request to withdraw a small amount of CASH
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    vm.expectEmit(true, true, true, true);
    emit RedemptionRequested(alice, 100e18, 0);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();
    // Have Bob request to withdraw a large amount of CASH
    vm.startPrank(bob);
    tokenProxied.approve(address(cashManager), LARGE_REDEMPTION);
    vm.expectEmit(true, true, true, true);
    emit RedemptionRequested(bob, LARGE_REDEMPTION, 0);
    cashManager.requestRedemption(LARGE_REDEMPTION);
    vm.stopPrank();

    // Move forward to the next epoch and set exchange rate
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(125e6, 0);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(125e6);

    toWithdraw.push(alice);
    toWithdraw.push(bob);
    vm.prank(managerAdmin);
    // The amount of CASH that Alice intends to redemption is too small
    // to be computed.
    vm.expectRevert(ICashManager.CollateralRedemptionTooSmall.selector);
    cashManager.completeRedemptions(toWithdraw, toRefund, 1, 0, 0);
  }

  function test_unit_complete_redeem_failKYC() public {
    // Set up the test
    _seed(100e18, 0, 0);
    // Have alice request to withdraw 100 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(125e3, 0);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(125e6);

    toWithdraw.push(alice);
    _removeAddressFromKYC(kycRequirementGroup, alice);
    // Assert we can not interact with non-KYC'd address
    vm.expectRevert(ICashManager.KYCCheckFailed.selector);
    vm.prank(managerAdmin);
    cashManager.completeRedemptions(toWithdraw, toRefund, 125e6, 0, 5e6);
  }

  function test_unit_complete_refund_failKYC() public {
    // Set up the test
    _seed(100e18, 0, 0);
    // Have alice request to withdraw 100 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(125e3, 0);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(125e6);

    toRefund.push(alice);
    _removeAddressFromKYC(kycRequirementGroup, alice);
    // Assert we can not interact with non-KYC'd address
    vm.expectRevert(ICashManager.KYCCheckFailed.selector);
    vm.prank(managerAdmin);
    cashManager.completeRedemptions(toWithdraw, toRefund, 125e6, 0, 5e6);
  }

  function test_unit_redeem_singleUser_partial() public {
    _seed(200e18, 0, 0);

    // Have alice request to withdraw 100 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(2e6, 0);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(200e6);

    toWithdraw.push(alice);
    vm.prank(managerAdmin);
    cashManager.completeRedemptions(toWithdraw, toRefund, 200e6, 0, 10e6);
    assertEq(usdc.balanceOf(alice), 190e6);
    assertEq(usdc.balanceOf(address(feeRecipient)), 10e6);
    assertEq(tokenProxied.balanceOf(alice), 100e18);
  }

  function test_unit_redeemAirdrop() public {
    // Seed alice and bob with 100 cash tokens
    _seed(100e18, 100e18, 0);

    // Have alice request to withdraw 100 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Have bob request to withdraw 100 cash tokens
    vm.startPrank(bob);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(2e6, 0);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(300e6);

    // Airdrop Alice and bob their collateral
    toWithdraw.push(alice);
    toWithdraw.push(bob);

    vm.prank(managerAdmin);
    cashManager.completeRedemptions(
      toWithdraw, // Addresses to issue collateral to
      toRefund, // Addresses to refund cash
      300e6, // Total amount of money to dist incl fees
      0, // Epoch we wish to process
      6e6 // Fee amount to be transferred to ondo
    );

    assertEq(usdc.balanceOf(alice), 147e6);
    assertEq(usdc.balanceOf(bob), 147e6);
    assertEq(usdc.balanceOf(feeRecipient), 6e6);
  }

  function test_unit_redeem_refundOnly() public {
    // Seed alice with 200 Cash tokens
    _seed(200e18, 0, 0);

    // Have alice request to withdraw 200 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 200e18);
    cashManager.requestRedemption(200e18);
    vm.stopPrank();

    assertEq(tokenProxied.balanceOf(alice), 0);

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(2e6, 0);

    // Issue alice a refund
    toRefund.push(alice);

    vm.prank(managerAdmin);
    cashManager.completeRedemptions(
      toWithdraw, // Addresses to issue collateral to
      toRefund, // Addresses to refund cash
      0, // Total amount of money to dist incl fees
      0, // Epoch we wish to process
      0 // Fee amount to be transferred to ondo
    );

    assertEq(tokenProxied.balanceOf(alice), 200e18);
  }

  function test_unit_redeem_redeemRefund() public {
    // Seed alice and bob with 200 cash tokens
    _seed(200e18, 200e18, 50e18);

    // Have alice request to withdraw 200 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 200e18);
    cashManager.requestRedemption(200e18);
    vm.stopPrank();

    // Have bob request to withdraw 200 cash tokens
    vm.startPrank(bob);
    tokenProxied.approve(address(cashManager), 200e18);
    cashManager.requestRedemption(200e18);
    vm.stopPrank();

    // Have charlie request to withdraw his tokens
    vm.startPrank(charlie);
    tokenProxied.approve(address(cashManager), 50e18);
    cashManager.requestRedemption(50e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(2e6, 0);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(300e6);

    // Airdrop Alice and bob their collateral
    toWithdraw.push(alice);
    toWithdraw.push(bob);

    // Issue charlie a refund for whatever reason
    toRefund.push(charlie);

    vm.prank(managerAdmin);
    cashManager.completeRedemptions(
      toWithdraw, // Addresses to issue collateral to
      toRefund, // Addresses to refund cash
      300e6, // Total amount of money to dist incl fees
      0, // Epoch we wish to process
      6e6 // Fee amount to be transferred to ondo
    );

    assertEq(usdc.balanceOf(alice), 147e6);
    assertEq(usdc.balanceOf(bob), 147e6);
    assertEq(tokenProxied.balanceOf(charlie), 50e18);
  }

  function test_unit_redeem_multiple_redeemers() public {
    _removeRedeemLimit();
    _seed(500e18, 2000e18, 50e18);

    // Have alice request to withdraw 200 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 200e18);
    cashManager.requestRedemption(200e18);
    vm.stopPrank();

    // Have alice request to withdraw 1000 cash tokens
    vm.startPrank(bob);
    tokenProxied.approve(address(cashManager), 1000e18);
    cashManager.requestRedemption(1000e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(2e6, 0);

    // Approve the cashManager contract from the assetSender account
    _seedSenderWithCollateral(1850e6);

    // Airdrop Alice and bob their collateral
    toWithdraw.push(alice);
    toWithdraw.push(bob);

    vm.prank(managerAdmin);
    cashManager.completeRedemptions(
      toWithdraw, // Addresses to issue collateral to
      toRefund, // Addresses to refund cash
      1850e6, // Total amount of money to dist incl fees
      0, // Epoch we wish to process
      50e6 // Fee amount to be transferred to ondo
    );

    // assert that bob gets 5/6ths of the total amount - fees
    uint256 expectedBob = (5 * 1800e6) / 6;
    uint256 expectedAlice = 1800e6 / 6;
    assertEq(usdc.balanceOf(alice), expectedAlice);
    assertEq(usdc.balanceOf(bob), expectedBob);
    assertEq(usdc.balanceOf(feeRecipient), 50e6);
  }

  function test_unit_redeemAirdrop_100Users() public {
    _removeRedeemLimit();

    for (uint256 i = 0; i < 100; ++i) {
      _seedUser(users[i]);
      vm.startPrank(users[i]);
      tokenProxied.approve(address(cashManager), 100e18);
      cashManager.requestRedemption(100e18);
      toWithdraw.push(users[i]);
      vm.stopPrank();
    }

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    cashManager.setMintExchangeRate(2e6, 0);

    _seedSenderWithCollateral(51_00e6);
    vm.prank(managerAdmin);
    cashManager.completeRedemptions(
      toWithdraw, // Addresses to issue collateral to
      toRefund, // Addresses to refund cash
      5100e6, // Total amount of money to dist incl fees
      0, // Epoch we wish to process
      1_000e6 // Fee amount to be transferred to ondo
    );
  }

  function test_unit_redeem_clear_pending() public {
    _seed(100e18, 100e18, 0);

    // Have alice request to withdraw 100 cash tokens
    vm.startPrank(alice);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    vm.startPrank(bob);
    tokenProxied.approve(address(cashManager), 100e18);
    cashManager.requestRedemption(100e18);
    vm.stopPrank();

    // Move forward to the next epoch
    vm.warp(block.timestamp + 1 days);
    vm.prank(managerAdmin);
    vm.expectEmit(true, true, true, true);
    emit PendingRedemptionBalanceSet(alice, 0, 0, 100e18);
    cashManager.setPendingRedemptionBalance(alice, 0, 0);
    // Bob still has 100 pending
    assertEq(cashManager.redemptionInfoPerEpoch(0), 100e18);
    assertEq(cashManager.getBurnedQuantity(0, alice), 0);
    assertEq(cashManager.getBurnedQuantity(0, bob), 100e18);

    // Approve the cashMinter contract from the assetSender account
    _seedSenderWithCollateral(200e6);

    toWithdraw.push(bob);
    vm.prank(managerAdmin);
    cashManager.completeRedemptions(toWithdraw, toRefund, 200e6, 0, 10e6);
    assertEq(tokenProxied.balanceOf(alice), 0);
    assertEq(tokenProxied.balanceOf(bob), 0);
    assertEq(usdc.balanceOf(address(feeRecipient)), 10e6);
    assertEq(usdc.balanceOf(alice), 0);
    assertEq(usdc.balanceOf(bob), 190e6);
  }

  /*//////////////////////////////////////////////////////////////
                     Helper functions
  //////////////////////////////////////////////////////////////*/

  function _seedUser(address user) internal {
    vm.prank(guardian);
    tokenProxied.mint(user, 100e18);
    vm.stopPrank();
  }

  function _removeRedeemLimit() internal {
    vm.prank(managerAdmin);
    cashManager.setRedeemLimit(type(uint256).max);
  }

  function _seed(
    uint256 aliceAmt,
    uint256 bobAmt,
    uint256 charlieAmt
  ) internal {
    vm.startPrank(guardian);
    tokenProxied.mint(alice, aliceAmt);
    tokenProxied.mint(bob, bobAmt);
    tokenProxied.mint(charlie, charlieAmt);
    vm.stopPrank();
  }

  function _seedSenderWithCollateral(uint256 usdcAmount) internal {
    vm.prank(usdcWhale);
    usdc.transfer(assetSender, usdcAmount);
    vm.prank(assetSender);
    usdc.approve(address(cashManager), usdcAmount);
  }
}
