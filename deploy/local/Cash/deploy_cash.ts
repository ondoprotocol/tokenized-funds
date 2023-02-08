import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
const { ethers } = require("hardhat");

const deployCash: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { save } = deployments;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;
  const signers = await ethers.getSigners();

  const guardian = signers[1];

  await deploy("CashFactory", {
    from: deployer,
    args: [guardian.address],
    log: true,
  });

  // Deploy Cash from the factory contract
  const factory = await ethers.getContract("CashFactory");
  await factory.connect(guardian).deployCash("Cash", "CASH");

  // Get proxy and proxyAdmin addresses
  const cashProxyAddress = await factory.cashProxy();
  const cashProxyAdminAddress = await factory.cashProxyAdmin();

  // Save Cash Token to deployments
  const artifact = await deployments.getExtendedArtifact("Cash");
  let cashProxied = {
    address: cashProxyAddress,
    ...artifact,
  };
  await save("Cash", cashProxied);

  // Save Cash Proxy Admin to deployments
  const proxyAdminArtifact = await deployments.getExtendedArtifact(
    "ProxyAdmin"
  );
  let cashProxyAdmin = {
    address: cashProxyAdminAddress,
    ...proxyAdminArtifact,
  };
  await save("ProxyAdminCash", cashProxyAdmin);

  const implementationAddress = await getImplementationAddress(
    ethers.provider,
    cashProxied.address
  );
  console.log("CASH Proxy is: ", cashProxyAddress);
  console.log("CASH Implementation is: ", implementationAddress);
  console.log("CASH ProxyAdmin is: ", cashProxyAdminAddress);
};

export default deployCash;
deployCash.tags = ["Cash", "Local"];
