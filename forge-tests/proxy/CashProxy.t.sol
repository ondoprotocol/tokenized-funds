// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-tests/BasicDeployment.sol";
import "contracts/Proxy.sol";

contract TestCashProxySetup is BasicDeployment {
  function setUp() public {
    createDeploymentCash();
  }

  function test_unit_guradian_is_proxy_admin_owner() public {
    address adminOwner = cashAdmin.owner();
    assertEq(adminOwner, address(guardian));
  }

  function test_unit_cash_only_approved_minters() public {
    uint256 minterRoleCount = tokenProxied.getRoleMemberCount(
      tokenProxied.MINTER_ROLE()
    );
    address firstMinter = tokenProxied.getRoleMember(
      tokenProxied.MINTER_ROLE(),
      0
    );
    address secondMinter = tokenProxied.getRoleMember(
      tokenProxied.MINTER_ROLE(),
      1
    );
    assertEq(minterRoleCount, 2);
    assertEq(firstMinter, guardian);
    assertEq(secondMinter, address(cashManager));
  }

  function test_unit_cash_only_approved_pausers() public {
    uint256 pauserRoleCount = tokenProxied.getRoleMemberCount(
      tokenProxied.PAUSER_ROLE()
    );
    assertEq(pauserRoleCount, 1);
    address pauserAddr = tokenProxied.getRoleMember(
      tokenProxied.PAUSER_ROLE(),
      0
    );
    assertEq(pauserAddr, guardian);
  }

  function test_unit_cash_only_approved_transferer() public {
    uint256 transferRoleCount = tokenProxied.getRoleMemberCount(
      keccak256("TRANSFER_ROLE")
    );
    address firstTransferer = tokenProxied.getRoleMember(
      keccak256("TRANSFER_ROLE"),
      0
    );
    address secondTransferer = tokenProxied.getRoleMember(
      keccak256("TRANSFER_ROLE"),
      1
    );
    assertEq(transferRoleCount, 2);
    assertEq(firstTransferer, guardian);
    assertEq(secondTransferer, address(cashManager));
  }

  function test_unit_cash_only_approved_default_admin() public {
    uint256 defaultAdminCount = tokenProxied.getRoleMemberCount(bytes32(0));
    address defaultAdminCashAddr = tokenProxied.getRoleMember(bytes32(0), 0);
    assertEq(defaultAdminCount, 1);
    assertEq(defaultAdminCashAddr, guardian);
  }

  function test_unit_token_implementation_cannot_be_initialized() public {
    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    cashImpl.initialize("Test", "Case");
  }

  function test_unit_non_owner_cannot_upgrade_implementation() public {
    vm.expectRevert();
    TokenProxy(payable(address(cashProxied))).upgradeToAndCall(address(3), "");
  }

  function test_unit_non_owner_cannot_transfer_ownership_proxyAdmin() public {
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    cashAdmin.transferOwnership(address(this));
  }

  function test_unit_approved_admin_can_update_implementation() public {
    CashUpgrade implv2 = new CashUpgrade();
    TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
      payable(address(tokenProxied))
    );

    vm.prank(guardian);
    cashAdmin.upgrade(proxy, address(implv2));
    vm.prank(guardian);
    address implCurrent = cashAdmin.getProxyImplementation(proxy);
    assertEq(implCurrent, address(implv2));

    CashUpgrade cashProxiedUpgraded = CashUpgrade(address(proxy));
    cashProxiedUpgraded.bypassMintingCheck(address(5), 500);
    uint256 result = cashProxiedUpgraded.balTimes50(address(5));
    assertEq(result, 500 * 50);

    vm.prank(address(1));
    cashProxiedUpgraded.noTokensForYou(address(5), 500);
    uint256 balAfter = cashProxiedUpgraded.balanceOf(address(5));
    assertEq(balAfter, 0);
  }
}

contract CashUpgrade is ERC20PresetMinterPauserUpgradeable {
  function balTimes50(address account) public view returns (uint256) {
    return balanceOf(account) * 50;
  }

  function bypassMintingCheck(address _to, uint256 _amt) external {
    _mint(_to, _amt);
  }

  function noTokensForYou(address _from, uint256 _amt) external {
    _burn(_from, _amt);
  }
}
