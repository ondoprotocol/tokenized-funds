pragma solidity 0.8.16;

import "forge-tests/lib/DSTestPlus.sol";
import "contracts/Proxy.sol";

import "contracts/factory/CashFactory.sol";
import "contracts/external/openzeppelin/contracts/proxy/ProxyAdmin.sol";

contract User {}

contract TestCashFactory is DSTestPlus {
  User guardian;
  CashFactory cashFactory;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);
  bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

  function setUp() public {
    guardian = new User();
    cashFactory = new CashFactory(address(guardian));
  }

  event CashDeployed(
    address proxy,
    address proxyAdmin,
    address implementation,
    string name,
    string ticker
  );

  function test_cash_factory_deploy_access_control() public {
    vm.expectRevert("CashFactory: You are not the Guardian");
    cashFactory.deployCash("Cash", "CASH");
  }

  function test_cash_factory_deploy() public {
    vm.prank(address(guardian));
    vm.expectEmit(true, true, true, false);
    emit CashDeployed(address(0x0), address(0x0), address(0x0), "Cash", "CASH");
    (address proxy, address admin, address impl) = cashFactory.deployCash(
      "Cash",
      "CASH"
    );

    Cash cash = Cash(proxy);
    ProxyAdmin proxyAdmin = ProxyAdmin(admin);
    // Guardian owns proxy admin.
    assertEq(proxyAdmin.owner(), address(guardian));

    // Assert cash proxy has correct admin and impl.
    vm.startPrank(admin);
    TokenProxy iProxy = TokenProxy(payable(proxy));
    assertEq(iProxy.admin(), admin);
    assertEq(iProxy.implementation(), impl);
    vm.stopPrank();

    assertEq(cash.totalSupply(), 0);

    assertEq(cash.getRoleAdmin(TRANSFER_ROLE), DEFAULT_ADMIN_ROLE);
    assertEq(cash.getRoleAdmin(MINTER_ROLE), DEFAULT_ADMIN_ROLE);
    assertEq(cash.getRoleAdmin(PAUSER_ROLE), DEFAULT_ADMIN_ROLE);

    assertEq(cash.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
    assertEq(cash.getRoleMemberCount(PAUSER_ROLE), 1);
    assertEq(cash.getRoleMember(PAUSER_ROLE, 0), address(guardian));
    assertEq(cash.getRoleMember(DEFAULT_ADMIN_ROLE, 0), address(guardian));

    // Minter and transfer role must be granted at a later stage.
    assertEq(cash.getRoleMemberCount(MINTER_ROLE), 0);
    assertEq(cash.getRoleMemberCount(TRANSFER_ROLE), 0);
  }
}
