// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";
import "forge-std/console2.sol";

contract TestKYCRegistry is BasicDeployment {
  address[] public addresses;

  function setUp() public {
    deployKYCRegistry();

    addresses.push(address(0x1));
    addresses.push(address(0x2));
    addresses.push(address(0x3));
  }

  function test_unit_registry_accessControl() public {
    assertEq(
      registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), registryAdmin),
      true
    );
    assertEq(registry.getRoleMemberCount(registry.DEFAULT_ADMIN_ROLE()), 1);
    assertEq(registry.hasRole(registry.REGISTRY_ADMIN(), registryAdmin), true);
    assertEq(registry.getRoleMemberCount(registry.REGISTRY_ADMIN()), 1);
    assertEq(
      registry.getRoleAdmin(registry.REGISTRY_ADMIN()),
      registry.DEFAULT_ADMIN_ROLE()
    );

    assertEq(registry.kycGroupRoles(kycRequirementGroup), KYC_GROUP_2_ROLE);
    assertEq(registry.kycGroupRoles(0), registry.DEFAULT_ADMIN_ROLE());
  }

  function test_unit_registry_addKYCAddress_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(bob, KYC_GROUP_2_ROLE));
    // Bob does not have appropriate role.
    vm.prank(bob);
    registry.addKYCAddresses(kycRequirementGroup, addresses);
  }

  function test_unit_registry_add_remove_defaultAdminRole() public {
    // Account with Default Admin Role is able to set
    // any level not already set.
    vm.startPrank(registryAdmin);
    registry.addKYCAddresses(0, addresses);
    registry.removeKYCAddresses(0, addresses);
    // We use onlyRole to gate add and removes, so default admin would
    // not be able to set an already set level directly.
    vm.expectRevert(_formatACRevert(registryAdmin, KYC_GROUP_2_ROLE));
    registry.addKYCAddresses(kycRequirementGroup, addresses);
    vm.expectRevert(_formatACRevert(registryAdmin, KYC_GROUP_2_ROLE));
    registry.removeKYCAddresses(kycRequirementGroup, addresses);
    vm.stopPrank();
  }

  function test_unit_role_level_assignment() public {
    // Bob should not be able to assign roles to kyc levels.
    vm.expectRevert(_formatACRevert(bob, registry.REGISTRY_ADMIN()));
    vm.prank(bob);
    registry.assignRoletoKYCGroup(kycRequirementGroup, KYC_GROUP_2_ROLE);
  }

  function test_unit_registry_addKYCAddresses() public {
    // Add KYC addresses
    registry.addKYCAddresses(kycRequirementGroup, addresses);

    // Check
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x0)), false);
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x1)), true);
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x2)), true);
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x3)), true);
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x4)), false);
  }

  function test_unit_registry_removeKYCAddress_fail_accessControl() public {
    vm.expectRevert(_formatACRevert(bob, KYC_GROUP_2_ROLE));
    vm.prank(bob);
    registry.removeKYCAddresses(kycRequirementGroup, addresses);
  }

  function test_unit_registry_removeKYCAddress() public {
    // Add KYC addresses
    registry.addKYCAddresses(kycRequirementGroup, addresses);

    // Remove KYC addresses
    address[] memory addressesToRemove = new address[](2);
    addressesToRemove[0] = address(0x1);
    addressesToRemove[1] = address(0x3);
    registry.removeKYCAddresses(kycRequirementGroup, addressesToRemove);

    // Check
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x1)), false);
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x2)), true);
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x3)), false);
  }

  function test_unit_sanctions() public {
    registry.addKYCAddresses(kycRequirementGroup, addresses);
    assertTrue(address(registry.sanctionsList()) != address(0));
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x2)), true);
    _addAddressToSanctionsList(address(0x2));
    assertEq(registry.getKYCStatus(kycRequirementGroup, address(0x2)), false);
  }

  function test_unit_events() public {
    vm.expectEmit(true, true, true, true);
    emit KYCAddressesAdded(address(this), kycRequirementGroup, addresses);
    registry.addKYCAddresses(kycRequirementGroup, addresses);

    vm.expectEmit(true, true, true, true);
    emit KYCAddressesRemoved(address(this), kycRequirementGroup, addresses);
    registry.removeKYCAddresses(kycRequirementGroup, addresses);

    bytes32 OTHER_KYC_GROUP_2_ROLE = keccak256("KYC_GROUP_X");
    vm.expectEmit(true, true, true, true);
    emit RoleAssignedToKYCGroup(99, OTHER_KYC_GROUP_2_ROLE);
    vm.prank(registryAdmin);
    registry.assignRoletoKYCGroup(99, OTHER_KYC_GROUP_2_ROLE);
  }
}
