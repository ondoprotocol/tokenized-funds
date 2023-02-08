/**SPDX-License-Identifier: BUSL-1.1

      ▄▄█████████▄
   ╓██▀└ ,╓▄▄▄, '▀██▄
  ██▀ ▄██▀▀╙╙▀▀██▄ └██µ           ,,       ,,      ,     ,,,            ,,,
 ██ ,██¬ ▄████▄  ▀█▄ ╙█▄      ▄███▀▀███▄   ███▄    ██  ███▀▀▀███▄    ▄███▀▀███,
██  ██ ╒█▀'   ╙█▌ ╙█▌ ██     ▐██      ███  █████,  ██  ██▌    └██▌  ██▌     └██▌
██ ▐█▌ ██      ╟█  █▌ ╟█     ██▌      ▐██  ██ └███ ██  ██▌     ╟██ j██       ╟██
╟█  ██ ╙██    ▄█▀ ▐█▌ ██     ╙██      ██▌  ██   ╙████  ██▌    ▄██▀  ██▌     ,██▀
 ██ "██, ╙▀▀███████████⌐      ╙████████▀   ██     ╙██  ███████▀▀     ╙███████▀`
  ██▄ ╙▀██▄▄▄▄▄,,,                ¬─                                    '─¬
   ╙▀██▄ '╙╙╙▀▀▀▀▀▀▀▀
      ╙▀▀██████R⌐

 */
pragma solidity 0.8.16;

// Proxy admin contract used in OZ upgrades plugin
import "contracts/external/openzeppelin/contracts/proxy/ProxyAdmin.sol";
import "contracts/Proxy.sol";
import "contracts/token/Cash.sol";
import "contracts/interfaces/IMulticall.sol";

/**
 * @title CashFactory
 * @author Ondo Finance
 * @notice This contract serves as a Factory for the upgradable CASH token contract.
 *         Upon calling `deployCash` the `guardian` address (set in constructor) will
 *         deploy the following:
 *         1) cash - The implementation contract, ERC20 contract with the initializer disabled
 *         2) ProxyAdmin - OZ ProxyAdmin contract, used to upgrade the proxy instance.
 *                         @notice Owner is set to `guardian` address.
 *         3) TransparentUpgradeableProxy - OZ, proxy contract. Admin is set to `address(proxyAdmin)`.
 *                                          `_logic' is set to `address(cash)`.
 *
 *         Following the above mentioned deployment, the address of the CashFactory contract will:
 *         i) Grant the `DEFAULT_ADMIN_ROLE` & PAUSER_ROLE to the `guardian` address
 *         ii) Revoke the `MINTER_ROLE`, `PAUSER_ROLE` & `DEFAULT_ADMIN_ROLE` from address(this).
 *         iii) Transfer ownership of the ProxyAdmin to that of the `guardian` address.
 *
 * @notice `guardian` address in constructor is a msig.
 */
contract CashFactory is IMulticall {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);

  address internal immutable guardian;
  Cash public cashImplementation;
  ProxyAdmin public cashProxyAdmin;
  TokenProxy public cashProxy;

  constructor(address _guardian) {
    guardian = _guardian;
  }

  /**
   * @dev This function will deploy an upgradable instance of Cash
   *
   * @param name   The name of the token we want to deploy.
   * @param ticker The ticker for the token we want to deploy.
   *
   * @return address The address of the proxy contract.
   * @return address The address of the proxyAdmin contract.
   * @return address The address of the implementation contract.
   *
   * @notice 1) Will automatically revoke all deployer roles granted to
   *            address(this).
   *         2) Will grant DEFAULT_ADMIN & PAUSER_ROLE(S) to `guardian`
   *            address specified in constructor.
   *         3) Will transfer ownership of the proxyAdmin to guardian
   *            address.
   *
   */
  function deployCash(
    string calldata name,
    string calldata ticker
  ) external onlyGuardian returns (address, address, address) {
    cashImplementation = new Cash();
    cashProxyAdmin = new ProxyAdmin();
    cashProxy = new TokenProxy(
      address(cashImplementation),
      address(cashProxyAdmin),
      ""
    );
    Cash cashProxied = Cash(address(cashProxy));
    cashProxied.initialize(name, ticker);

    cashProxied.grantRole(DEFAULT_ADMIN_ROLE, guardian);
    cashProxied.grantRole(PAUSER_ROLE, guardian);

    cashProxied.revokeRole(MINTER_ROLE, address(this));
    cashProxied.revokeRole(PAUSER_ROLE, address(this));
    cashProxied.revokeRole(DEFAULT_ADMIN_ROLE, address(this));

    cashProxyAdmin.transferOwnership(guardian);
    assert(cashProxyAdmin.owner() == guardian);
    emit CashDeployed(
      address(cashProxied),
      address(cashProxyAdmin),
      address(cashImplementation),
      name,
      ticker
    );
    return (
      address(cashProxied),
      address(cashProxyAdmin),
      address(cashImplementation)
    );
  }

  /**
   * @notice Allows for arbitrary batched calls
   *
   * @dev All external calls made through this function will
   *      msg.sender == contract address
   *
   * @param exCallData Struct consisting of
   *       1) target - contract to call
   *       2) data - data to call target with
   *       3) value - eth value to call target with
   */
  function multiexcall(
    ExCallData[] calldata exCallData
  ) external payable override onlyGuardian returns (bytes[] memory results) {
    results = new bytes[](exCallData.length);
    for (uint256 i = 0; i < exCallData.length; ++i) {
      (bool success, bytes memory ret) = address(exCallData[i].target).call{
        value: exCallData[i].value
      }(exCallData[i].data);
      require(success, "Call Failed");
      results[i] = ret;
    }
  }

  /**
   * @dev Event emitted when upgradable cash is deployed
   *
   * @param proxy             The address for the proxy contract
   * @param proxyAdmin        The address for the proxy admin contract
   * @param implementation    The address for the implementation contract
   */
  event CashDeployed(
    address proxy,
    address proxyAdmin,
    address implementation,
    string name,
    string ticker
  );

  modifier onlyGuardian() {
    require(msg.sender == guardian, "CashFactory: You are not the Guardian");
    _;
  }
}
