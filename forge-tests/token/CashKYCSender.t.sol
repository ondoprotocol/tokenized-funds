// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";

contract TestCashKYCSenderToken is BasicDeployment {
  function setUp() public {
    deployKYCRegistry();
    deployCashKYCSenderToken();

    // Add KYC addresses
    address[] memory addressesToKYC = new address[](2);
    addressesToKYC[0] = guardian;
    addressesToKYC[1] = registryAdmin;
    registry.addKYCAddresses(kycRequirementGroup, addressesToKYC);
  }

  function test_unit_CashKYCSenderToken_pause() public {
    vm.prank(guardian);
    cashKYCSenderProxied.pause();
    assertEq(cashKYCSenderProxied.paused(), true);
  }

  function test_unit_CashKYCSenderToken_mint_fail_paused() public {
    // Pause Contract
    vm.startPrank(guardian);
    cashKYCSenderProxied.pause();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashKYCSenderProxied.mint(address(this), 1);
  }

  function test_unit_CashKYCSenderToken_mint_fail_nonKYC_initializer() public {
    // Remove guardian from KYC
    _removeAddressFromKYC(kycRequirementGroup, guardian);

    // Expect Revert
    vm.expectRevert("CashKYCSender: must be KYC'd to initiate transfer");
    vm.prank(guardian);
    cashKYCSenderProxied.mint(address(this), 1);
  }

  function test_unit_CashKYCSenderToken_mint() public {
    vm.prank(guardian);
    cashKYCSenderProxied.mint(address(this), 1);
    assertEq(cashKYCSenderProxied.balanceOf(address(this)), 1);
  }

  function test_unit_CashKYCSenderToken_transfer_fail_paused() public {
    // Mint
    vm.startPrank(guardian);
    cashKYCSenderProxied.mint(address(this), 1); // Mint to current contract

    // Pause
    cashKYCSenderProxied.pause();
    vm.stopPrank();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashKYCSenderProxied.transfer(alice, 1);
  }

  function test_unit_CashKYCSenderToken_transfer_fail_nonKYC_initializer()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderProxied.mint(bob, 1); // Mint to Bob

    // Expect Revert
    vm.expectRevert("CashKYCSender: must be KYC'd to initiate transfer");
    vm.prank(bob);
    cashKYCSenderProxied.transfer(alice, 1);

    // Note: Can't revert `transfer` with passing initializer and failing from
    // because initializer would fail first, need to test with transferFrom
  }

  // Tests that contract reverts on pause before transfer if addresses are not KYC'd
  function test_unit_cashToken_transfer_fail_pauseBeforeKYC() public {
    // Mint to current contract
    vm.startPrank(guardian);

    cashKYCSenderProxied.mint(address(this), 1);

    // Pause
    cashKYCSenderProxied.pause();
    vm.stopPrank();

    // Expect Revert
    vm.expectRevert("ERC20Pausable: token transfer while paused");
    cashKYCSenderProxied.transfer(alice, 1);
  }

  function test_unit_CashKYCSenderToken_transfer() public {
    // Mint
    vm.prank(guardian);
    cashKYCSenderProxied.mint(address(this), 1);

    // KYC testRunner
    _addAddressToKYC(kycRequirementGroup, address(this));

    // Transfer to alice
    cashKYCSenderProxied.transfer(alice, 1);
    assertEq(cashKYCSenderProxied.balanceOf(alice), 1);
    assertEq(cashKYCSenderProxied.balanceOf(address(this)), 0);
  }

  function test_unit_CashKYCSenderToken_transferFrom_fail_nonKYC_initializer_approveSelf()
    public
  {
    vm.prank(guardian);
    // Mint to Bob
    cashKYCSenderProxied.mint(bob, 1);

    // Bob to approve himself
    vm.prank(bob);
    cashKYCSenderProxied.approve(bob, 1);

    // Expect Revert
    vm.expectRevert("CashKYCSender: must be KYC'd to initiate transfer");
    vm.prank(bob);
    cashKYCSenderProxied.transferFrom(bob, alice, 1);
  }

  function test_unit_CashKYCSenderToken_transferFrom_fail_nonKYC_initializer()
    public
  {
    // Mint
    vm.prank(guardian);
    cashKYCSenderProxied.mint(address(this), 1); // Mint to current contract

    // Approve
    cashKYCSenderProxied.approve(alice, 1);

    // Expect Revert
    vm.expectRevert("CashKYCSender: must be KYC'd to initiate transfer");
    vm.prank(alice);
    cashKYCSenderProxied.transferFrom(address(this), alice, 1);
  }

  function test_unit_CashKYCSenderToken_transferFrom_fail_nonKYC_from() public {
    // Mint
    vm.prank(guardian);
    // Mint to Bob (Not KYCd)
    cashKYCSenderProxied.mint(bob, 1);

    // Bob to approve guardian
    vm.prank(bob);
    cashKYCSenderProxied.approve(guardian, 1);

    // Expect Revert
    vm.expectRevert(
      "CashKYCSender: `from` address must be KYC'd to send tokens"
    );
    vm.prank(guardian);
    cashKYCSenderProxied.transferFrom(bob, alice, 1);
  }

  function test_unit_CashKYCSenderToken_transferFrom() public {
    // Mint
    vm.prank(guardian);
    cashKYCSenderProxied.mint(address(this), 1);

    // KYC alice & testRunner
    _addAddressToKYC(kycRequirementGroup, alice);
    _addAddressToKYC(kycRequirementGroup, address(this));

    // Approve Transfer to alice
    cashKYCSenderProxied.approve(alice, 1);
    vm.prank(alice);
    cashKYCSenderProxied.transferFrom(address(this), alice, 1);

    // Check balances
    assertEq(cashKYCSenderProxied.balanceOf(address(this)), 0);
    assertEq(cashKYCSenderProxied.balanceOf(alice), 1);
  }

  function test_unit_CashKYCSenderToken_setKYCRequirementGroup() public {
    // Fail because of access control check
    vm.expectRevert(
      _formatACRevert(guardian, cashKYCSenderProxied.KYC_CONFIGURER_ROLE())
    );
    vm.startPrank(guardian);
    cashKYCSenderProxied.setKYCRequirementGroup(55);
    // Properly set role.
    cashKYCSenderProxied.grantRole(
      cashKYCSenderProxied.KYC_CONFIGURER_ROLE(),
      address(this)
    );
    vm.stopPrank();

    // Call setter successfully
    uint256 oldRequirementGroup = cashKYCSenderProxied.kycRequirementGroup();
    vm.expectEmit(true, true, true, true);
    emit KYCRequirementGroupSet(oldRequirementGroup, 55);
    cashKYCSenderProxied.setKYCRequirementGroup(55);
    assertEq(cashKYCSenderProxied.kycRequirementGroup(), 55);
  }

  function test_unit_CashKYCSenderToken_setKYCRegistry() public {
    // Fail because of access control check
    vm.expectRevert(
      _formatACRevert(guardian, cashKYCSenderProxied.KYC_CONFIGURER_ROLE())
    );
    vm.startPrank(guardian);
    cashKYCSenderProxied.setKYCRegistry(address(55));

    // Properly set role.
    cashKYCSenderProxied.grantRole(
      cashKYCSenderProxied.KYC_CONFIGURER_ROLE(),
      address(this)
    );
    vm.stopPrank();

    // Call setter successfully
    address oldRegistry = address(cashKYCSenderProxied.kycRegistry());
    vm.expectEmit(true, true, true, true);
    emit KYCRegistrySet(oldRegistry, address(55));
    cashKYCSenderProxied.setKYCRegistry(address(55));
    assertEq(address(cashKYCSenderProxied.kycRegistry()), address(55));
  }
}
