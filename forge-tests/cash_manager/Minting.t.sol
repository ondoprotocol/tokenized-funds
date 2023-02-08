// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";

abstract contract TestCashMinting is BasicDeployment {
  /*//////////////////////////////////////////////////////////////
                            Request Mint
  //////////////////////////////////////////////////////////////*/

  function test_unit_requestMint_fail_paused() public {
    vm.prank(pauser);
    cashManager.pause();

    usdc.approve(address(cashManager), 1e6);
    vm.expectRevert("Pausable: paused");
    cashManager.requestMint(1e6);
  }

  function test_unit_requestMint_fail_lowCollateral() public {
    usdc.approve(address(cashManager), 1);
    // Minimum deposit amount is 1e5 USDC
    vm.expectRevert(ICashManager.MintRequestAmountTooSmall.selector);
    cashManager.requestMint(1);
  }

  function test_unit_requestMint_no_fees() public {
    usdc.approve(address(cashManager), 1e6);

    vm.expectEmit(true, true, true, true);
    emit MintRequested(address(this), 0, 1e6, 1e6, 0);
    uint256 balBefore = usdc.balanceOf(address(this));

    cashManager.requestMint(1e6);

    // Checks
    assertEq(usdc.balanceOf(cashManager.assetRecipient()), 1e6);
    assertEq(cashManager.mintRequestsPerEpoch(0, address(this)), 1e6);
    assertEq(usdc.balanceOf(address(this)), balBefore - 1e6);
  }

  function setMintFee(uint256 fee) public {
    vm.prank(managerAdmin);
    cashManager.setMintFee(fee);
  }

  function test_unit_requestMint_fees() public {
    setMintFee(1000); // 10% fee

    usdc.approve(address(cashManager), 1e6);
    vm.expectEmit(true, true, true, true);
    emit MintRequested(address(this), 0, 1e6, 9e5, 1e5);
    cashManager.requestMint(1e6);

    // Checks
    assertEq(usdc.balanceOf(cashManager.assetRecipient()), 9e5); // 1e6 = 1e5 + 9e5
    assertEq(usdc.balanceOf(cashManager.feeRecipient()), 1e5);
    assertEq(cashManager.mintRequestsPerEpoch(0, address(this)), 9e5);
  }

  function test_unit_requestMint_failKYC() public {
    usdc.approve(address(cashManager), 1e6);
    _removeAddressFromKYC(kycRequirementGroup, address(this));
    vm.expectRevert(ICashManager.KYCCheckFailed.selector);
    cashManager.requestMint(1e6);
  }

  /*//////////////////////////////////////////////////////////////
                        Request Mint Limit
  //////////////////////////////////////////////////////////////*/

  function test_unit_requestMint_fail_exceedsLimit() public {
    usdc.approve(address(cashManager), 1001e6);

    vm.expectRevert(ICashManager.MintExceedsRateLimit.selector);
    cashManager.requestMint(1001e6);
  }

  function test_fuzz_requestMintLimit_sameEpoch(uint256 usdcAmountIn) public {
    vm.assume(usdcAmountIn >= cashManager.minimumDepositAmount());
    vm.assume(usdcAmountIn < INIT_BALANCE_USDC);

    usdc.approve(address(cashManager), usdcAmountIn);

    if (usdcAmountIn > cashManager.mintLimit()) {
      vm.expectRevert(ICashManager.MintExceedsRateLimit.selector);
      cashManager.requestMint(usdcAmountIn);
    } else {
      // Else check that currentMintAmount updated
      cashManager.requestMint(usdcAmountIn);
      assertEq(
        cashManager.mintRequestsPerEpoch(0, address(this)),
        usdcAmountIn
      );
    }
  }

  /*//////////////////////////////////////////////////////////////
                        Request Mint and Claim
  //////////////////////////////////////////////////////////////*/

  function test_unit_claimMint_approved_can_claim() public {
    // Setup CM
    usdc.approve(address(cashManager), 1e6);
    cashManager.requestMint(1e6);

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    // Check events
    vm.expectEmit(true, true, true, true);
    emit MintCompleted(address(this), 1e18, 1e6, 1e6, 0);
    cashManager.claimMint(address(this), 0);

    assertEq(tokenProxied.balanceOf(address(this)), 1e18);
  }

  function test_unit_claimMint_failKYC() public {
    // Setup CM
    usdc.approve(address(cashManager), 1e6);
    cashManager.requestMint(1e6);

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);
    // Guardian should have KYC status
    _addAddressToKYC(kycRequirementGroup, guardian);
    // Remove KYC status from this contract's address
    _removeAddressFromKYC(kycRequirementGroup, address(this));
    // Guardian triggers mint destined for `this`
    vm.prank(guardian);
    vm.expectRevert(ICashManager.KYCCheckFailed.selector);
    cashManager.claimMint(address(this), 0);
  }

  function test_unit_claimMint_passKYC() public {
    // Setup CM
    usdc.approve(address(cashManager), 1e6);
    cashManager.requestMint(1e6);

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);
    // Remove KYC status from the guardian address
    _removeAddressFromKYC(kycRequirementGroup, guardian);
    // Guardian triggers mint destined for `this`
    // Since the minted cash is not destined for guardian,
    // this call will still succeed.
    vm.prank(guardian);
    cashManager.claimMint(address(this), 0);
    assertEq(tokenProxied.balanceOf(address(this)), 1e18);
  }

  function test_unit_claimMint_fail_cannot_claim_twice() public {
    // Setup CM
    usdc.approve(address(cashManager), 1e6);
    cashManager.requestMint(1e6);

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);
    cashManager.claimMint(address(this), 0);
    assertEq(tokenProxied.balanceOf(address(this)), 1e18);

    vm.expectRevert(ICashManager.NoCashToClaim.selector);
    cashManager.claimMint(address(this), 0);
  }

  function test_unit_claimMint_fail_nothing_to_claim() public {
    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);
    vm.expectRevert(ICashManager.NoCashToClaim.selector);
    cashManager.claimMint(address(this), 0);
  }

  function test_unit_claimMint_fail_exchangeRateNotSet() public {
    // Setup CM
    usdc.approve(address(cashManager), 1e6);
    cashManager.requestMint(1e6);

    vm.warp(block.timestamp + 1 days);
    vm.expectRevert(ICashManager.ExchangeRateNotSet.selector);
    cashManager.claimMint(address(this), 0);
  }

  function test_unit_claimMint_claim_on_behalf_of() public {
    // Setup CM
    usdc.approve(address(cashManager), 1e6);
    cashManager.requestMint(1e6);

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    vm.prank(managerAdmin);
    cashManager.claimMint(address(this), 0);

    assertEq(tokenProxied.balanceOf(address(this)), 1e18);
    assertEq(tokenProxied.balanceOf(managerAdmin), 0);
  }

  function test_unit_claimMint_with_fees() public {
    // Setup CM
    setMintFee(1000);
    usdc.approve(address(cashManager), 1e6);
    cashManager.requestMint(1e6);

    vm.warp(block.timestamp + 1 days);
    cashManager.setMintExchangeRate(1e6, 0);

    cashManager.claimMint(address(this), 0);

    // After 10% fee, collateral after fees is 9e5, so 9e17 is minted
    assertEq(tokenProxied.balanceOf(address(this)), 9e17);
  }

  function test_unit_mint_clear_pending() public {
    vm.prank(usdcWhale);
    usdc.transfer(alice, 1000e6);
    vm.prank(alice);
    usdc.approve(address(cashManager), 10e6);

    vm.expectEmit(true, true, true, true);
    emit MintRequested(alice, 0, 10e6, 10e6, 0);
    vm.prank(alice);
    cashManager.requestMint(10e6);

    assertEq(usdc.balanceOf(cashManager.assetRecipient()), 10e6);
    assertEq(cashManager.mintRequestsPerEpoch(0, alice), 10e6);
    assertEq(usdc.balanceOf(alice), 990e6);

    // Clear pending balance.
    vm.expectEmit(true, true, true, true);
    emit PendingMintBalanceSet(alice, 0, 10e6, 0);
    vm.prank(managerAdmin);
    cashManager.setPendingMintBalance(alice, 0, 10e6, 0);
    assertEq(cashManager.mintRequestsPerEpoch(0, alice), 0);
    vm.warp(block.timestamp + 1 days);

    // Enable claims on epoch 0 by setting exchange rate
    cashManager.setMintExchangeRate(1e6, 0);
    // Claim fails because Alice's pending deposit amount was
    // deleted
    vm.prank(alice);
    vm.expectRevert(ICashManager.NoCashToClaim.selector);
    cashManager.claimMint(alice, 0);
  }
}
