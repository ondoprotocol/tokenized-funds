// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";

contract TestCashKYCSenderReceiverToken is BasicDeployment {
  function setUp() public {
    deployKYCRegistry();
    deployCashKYCSenderReceiverToken();

    // Add KYC addresses
    address[] memory addressesToKYC = new address[](3);
    addressesToKYC[0] = guardian;
    addressesToKYC[1] = registryAdmin;
    addressesToKYC[2] = address(this);
    registry.addKYCAddresses(kycRequirementGroup, addressesToKYC);
  }

  function test_unit_CashKYCSenderReceiverToken_pause() public {
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.pause();
    assertEq(cashKYCSenderReceiverProxied.paused(), true);
  }

  function test_unit_CashKYCSenderReceiverToken_mint_fail_paused() public {
    // Pause Contract
    vm.startPrank(guardian);
    cashKYCSenderReceiverProxied.pause();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashKYCSenderReceiverProxied.mint(address(this), 1);
  }

  function test_unit_CashKYCSenderReceiverToken_mint_fail_nonKYC_initializer()
    public
  {
    // Remove guardian from KYC
    _removeAddressFromKYC(kycRequirementGroup, guardian);

    // Expect Revert
    vm.expectRevert(
      "CashKYCSenderReceiver: must be KYC'd to initiate transfer"
    );
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);
  }

  function test_unit_CashKYCSenderReceiverToken_mint_fail_nonKYC_receiver()
    public
  {
    // Expect Revert
    vm.prank(guardian);
    vm.expectRevert(
      "CashKYCSenderReceiver: `to` address must be KYC'd to receive tokens"
    );
    cashKYCSenderReceiverProxied.mint(alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_mint() public {
    // Add testRunner to KYC
    _addAddressToKYC(kycRequirementGroup, address(this));
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);
    assertEq(cashKYCSenderReceiverProxied.balanceOf(address(this)), 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transfer_fail_paused() public {
    // Mint
    vm.startPrank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Pause
    cashKYCSenderReceiverProxied.pause();
    vm.stopPrank();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashKYCSenderReceiverProxied.transfer(alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transfer_fail_nonKYC_initializer()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Remove from KYC list
    _removeAddressFromKYC(kycRequirementGroup, address(this));

    // Expect Revert
    vm.expectRevert(
      "CashKYCSenderReceiver: must be KYC'd to initiate transfer"
    );
    cashKYCSenderReceiverProxied.transfer(alice, 1);

    // Note: Can't revert `transfer` with passing initializer and failing from
    // because initializer would fail first, need to test with transferFrom
  }

  // Tests that contract reverts on pause before transfer if addresses are not KYC'd
  function test_unit_cashToken_transfer_fail_pauseBeforeKYC() public {
    // Mint to current contract
    vm.startPrank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Pause
    cashKYCSenderReceiverProxied.pause();
    vm.stopPrank();

    //Remove from KYC list
    _removeAddressFromKYC(kycRequirementGroup, address(this));

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashKYCSenderReceiverProxied.transfer(alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transfer() public {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // KYC Alice
    _addAddressToKYC(kycRequirementGroup, alice);

    // Transfer
    cashKYCSenderReceiverProxied.transfer(alice, 1);
    assertEq(cashKYCSenderReceiverProxied.balanceOf(address(this)), 0);
    assertEq(cashKYCSenderReceiverProxied.balanceOf(alice), 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transfer_fail_nonKYC_to()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Expect Revert
    vm.expectRevert(
      "CashKYCSenderReceiver: `to` address must be KYC'd to receive tokens"
    );
    cashKYCSenderReceiverProxied.transfer(alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transferFrom_fail_nonKYC_initializer_approveSelf()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Approve Self
    cashKYCSenderReceiverProxied.approve(address(this), 1);

    // Remove from KYC list
    _removeAddressFromKYC(kycRequirementGroup, address(this));

    // Expect Revert
    vm.expectRevert(
      "CashKYCSenderReceiver: must be KYC'd to initiate transfer"
    );
    cashKYCSenderReceiverProxied.transferFrom(address(this), alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transferFrom_fail_nonKYC_initializer()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Approve
    cashKYCSenderReceiverProxied.approve(alice, 1);

    // Expect Revert
    vm.expectRevert(
      "CashKYCSenderReceiver: must be KYC'd to initiate transfer"
    );
    vm.prank(alice);
    cashKYCSenderReceiverProxied.transferFrom(address(this), alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transferFrom_fail_nonKYC_from()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Approve
    cashKYCSenderReceiverProxied.approve(guardian, 1);

    // Remove from KYC list
    _removeAddressFromKYC(kycRequirementGroup, address(this));

    // Expect Revert
    vm.expectRevert(
      "CashKYCSenderReceiver: `from` address must be KYC'd to send tokens"
    );
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.transferFrom(address(this), alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transferFrom_fail_nonKYC_to()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Approve
    cashKYCSenderReceiverProxied.approve(guardian, 1);

    // Expect Revert
    vm.expectRevert(
      "CashKYCSenderReceiver: `to` address must be KYC'd to receive tokens"
    );
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.transferFrom(address(this), alice, 1);
  }

  function test_unit_CashKYCSenderReceiverToken_transferFrom() public {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Approve
    cashKYCSenderReceiverProxied.approve(alice, 1);

    // Add to KYC Lists
    _addAddressToKYC(kycRequirementGroup, alice);
    _addAddressToKYC(kycRequirementGroup, bob);

    // Transfer
    vm.prank(alice);
    cashKYCSenderReceiverProxied.transferFrom(address(this), bob, 1);

    // Check balances
    assertEq(cashKYCSenderReceiverProxied.balanceOf(address(this)), 0);
    assertEq(cashKYCSenderReceiverProxied.balanceOf(bob), 1);
  }

  function test_unit_CashKYCSenderReceiverToken_burn() public {
    // Mint
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.mint(address(this), 1);

    // Approve
    cashKYCSenderReceiverProxied.approve(guardian, 1);

    // Burn
    vm.prank(guardian);
    cashKYCSenderReceiverProxied.burnFrom(address(this), 1);

    // Check
    assertEq(cashKYCSenderReceiverProxied.balanceOf(address(this)), 0);
    assertEq(cashKYCSenderReceiverProxied.totalSupply(), 0);
  }

  function test_unit_CashKYCSenderReceiverToken_setKYCRequirementGroup()
    public
  {
    // Fail because of access control check
    vm.expectRevert(
      _formatACRevert(
        guardian,
        cashKYCSenderReceiverProxied.KYC_CONFIGURER_ROLE()
      )
    );
    vm.startPrank(guardian);
    cashKYCSenderReceiverProxied.setKYCRequirementGroup(55);
    // Properly set role
    cashKYCSenderReceiverProxied.grantRole(
      cashKYCSenderReceiverProxied.KYC_CONFIGURER_ROLE(),
      address(this)
    );
    vm.stopPrank();

    // Call setter successfully
    uint256 oldRequirementGroup = cashKYCSenderReceiverProxied
      .kycRequirementGroup();
    vm.expectEmit(true, true, true, true);
    emit KYCRequirementGroupSet(oldRequirementGroup, 55);
    cashKYCSenderReceiverProxied.setKYCRequirementGroup(55);
    assertEq(cashKYCSenderReceiverProxied.kycRequirementGroup(), 55);
  }

  function test_unit_CashKYCSenderReceiverToken_setKYCRegistry() public {
    // Fail because of access control check
    vm.expectRevert(
      _formatACRevert(
        guardian,
        cashKYCSenderReceiverProxied.KYC_CONFIGURER_ROLE()
      )
    );
    vm.startPrank(guardian);
    cashKYCSenderReceiverProxied.setKYCRegistry(address(55));
    // Properly set role
    cashKYCSenderReceiverProxied.grantRole(
      cashKYCSenderReceiverProxied.KYC_CONFIGURER_ROLE(),
      address(this)
    );
    vm.stopPrank();

    // Call setter successfully
    address oldRegistry = address(cashKYCSenderReceiverProxied.kycRegistry());
    vm.expectEmit(true, true, true, true);
    emit KYCRegistrySet(oldRegistry, address(55));
    cashKYCSenderReceiverProxied.setKYCRegistry(address(55));
    assertEq(address(cashKYCSenderReceiverProxied.kycRegistry()), address(55));
  }
}
