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
import "contracts/token/CashKYCSender.sol";
import "contracts/interfaces/IMulticall.sol";

/**
 * @title CashKYCSenderFactory
 * @author Ondo Finance
 * @notice This contract serves as a Factory for the upgradable CashKYCSender token contract.
 *         Upon calling `deployCashKYCSender` the `guardian` address (set in constructor) will
 *         deploy the following:
 *         1) CashKYCSender - The implementation contract, ERC20 contract with the initializer disabled
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
contract CashKYCSenderFactory is IMulticall {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);

  address internal immutable guardian;
  CashKYCSender public cashKYCSenderImplementation;
  ProxyAdmin public cashKYCSenderProxyAdmin;
  TokenProxy public cashKYCSenderProxy;

  constructor(address _guardian) {
    guardian = _guardian;
  }

  /**
   * @dev This function will deploy an upgradable instance of CashKYCSender
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
  function deployCashKYCSender(
    string calldata name,
    string calldata ticker,
    address registry,
    uint256 kycRequirementGroup
  ) external onlyGuardian returns (address, address, address) {
    cashKYCSenderImplementation = new CashKYCSender();
    cashKYCSenderProxyAdmin = new ProxyAdmin();
    cashKYCSenderProxy = new TokenProxy(
      address(cashKYCSenderImplementation),
      address(cashKYCSenderProxyAdmin),
      ""
    );
    CashKYCSender cashKYCSenderProxied = CashKYCSender(
      address(cashKYCSenderProxy)
    );
    cashKYCSenderProxied.initialize(
      name,
      ticker,
      registry,
      kycRequirementGroup
    );

    cashKYCSenderProxied.grantRole(DEFAULT_ADMIN_ROLE, guardian);
    cashKYCSenderProxied.grantRole(PAUSER_ROLE, guardian);

    cashKYCSenderProxied.revokeRole(MINTER_ROLE, address(this));
    cashKYCSenderProxied.revokeRole(PAUSER_ROLE, address(this));
    cashKYCSenderProxied.revokeRole(DEFAULT_ADMIN_ROLE, address(this));

    cashKYCSenderProxyAdmin.transferOwnership(guardian);
    assert(cashKYCSenderProxyAdmin.owner() == guardian);
    emit CashKYCSenderDeployed(
      address(cashKYCSenderProxied),
      address(cashKYCSenderProxyAdmin),
      address(cashKYCSenderImplementation),
      name,
      ticker,
      registry
    );
    return (
      address(cashKYCSenderProxied),
      address(cashKYCSenderProxyAdmin),
      address(cashKYCSenderImplementation)
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
   * @dev Event emitted when upgradable CashKYCSender is deployed
   *
   * @param proxy             The address for the proxy contract
   * @param proxyAdmin        The address for the proxy admin contract
   * @param implementation    The address for the implementation contract
   */
  event CashKYCSenderDeployed(
    address proxy,
    address proxyAdmin,
    address implementation,
    string name,
    string ticker,
    address registry
  );

  modifier onlyGuardian() {
    require(
      msg.sender == guardian,
      "CashKYCSenderFactory: You are not the Guardian"
    );
    _;
  }
}
