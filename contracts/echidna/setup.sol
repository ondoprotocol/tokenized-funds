// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "contracts/factory/CashFactory.sol";
import "contracts/factory/CashKYCSenderFactory.sol";
import "contracts/factory/CashKYCSenderReceiverFactory.sol";
import "contracts/token/Cash.sol";
import "contracts/token/CashKYCSender.sol";
import "contracts/token/CashKYCSenderReceiver.sol";
import "contracts/Proxy.sol";
import "contracts/CashManager.sol";
import "contracts/kyc/KYCRegistry.sol";
import "contracts/external/openzeppelin/contracts/proxy/ProxyAdmin.sol";
import "contracts/external/openzeppelin/contracts/token/IERC20.sol";
import "contracts/external/openzeppelin/contracts/token/ERC20.sol";
import "forge-tests/helpers/MockSanctionsOracle.sol";
import "contracts/external/openzeppelin/contracts-upgradeable/token/ERC20/ERC20PresetMinterPauserUpgradeable.sol";

contract Account {
  function proxy(
    address target,
    bytes memory _calldata
  ) public returns (bool success, bytes memory returnData) {
    (success, returnData) = address(target).call(_calldata);
  }
}

contract MockERC20 is ERC20 {
  constructor(
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) {}

  function mint(address account, uint256 amount) external {
    require(account != address(0), "Account is empty.");
    require(amount > 0, "amount is less than zero.");
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    require(account != address(0), "Account is empty.");
    require(amount > 0, "amount is less than zero.");
    _burn(account, amount);
  }

  function decimals() public pure override returns (uint8) {
    return 6;
  }
}

contract Setup_CashManager {
  uint256 constant NUM_USERS = 5;
  uint256 kycRequirementGroup = 2;
  bytes32 public constant KYC_GROUP_2_ROLE = keccak256("KYC_GROUP_2");
  uint256 userId;
  address guardian = address(this);
  address[] userAddress;

  Account[] users;
  Cash cashProxied;
  CashManager cashManager;
  KYCRegistry registry;
  MockERC20 usdc;

  constructor() {
    usdc = new MockERC20("USDC", "USDC");
    deployCashToken();
    deployCashManagerWithTokens(address(cashProxied), address(usdc));
    for (uint256 i = 0; i < NUM_USERS; ++i) {
      users.push(new Account());
      usdc.mint(address(users[i]), 1000e6);
      userAddress.push(address(users[i]));
    }
    registry.addKYCAddresses(kycRequirementGroup, userAddress);
  }

  function deployCashToken() private {
    CashFactory cashFactory = new CashFactory(address(this));
    MockSanctionsOracle sanctionsOracle = new MockSanctionsOracle();
    registry = new KYCRegistry(address(this), address(sanctionsOracle));
    (address proxy, , ) = cashFactory.deployCash("Cash", "CASH");
    cashProxied = Cash(proxy);
    cashProxied.grantRole(cashProxied.TRANSFER_ROLE(), address(this));
    cashProxied.grantRole(cashProxied.MINTER_ROLE(), address(this));
  }

  function deployCashManagerWithTokens(address cash, address _usdc) private {
    cashManager = new CashManager(
      _usdc,
      cash,
      address(this),
      address(this),
      address(10),
      address(11),
      address(12),
      100_000e6, // Mint limit
      100_000e18, // Redeem limit
      1 days, // Epoch Duration,
      address(registry),
      kycRequirementGroup
    );

    cashProxied.grantRole(keccak256("MINTER_ROLE"), address(cashManager));
    cashProxied.grantRole(keccak256("TRANSFER_ROLE"), address(cashManager));
    cashManager.grantRole(keccak256("SETTER_ADMIN"), address(this));
  }
}
