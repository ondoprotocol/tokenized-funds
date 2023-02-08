import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { BigNumber } from "ethers";
import { KYC_GROUP } from "./constants";
const { ethers } = require("hardhat");

const deployCashKYCSender: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { save } = deployments;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;
  const signers = await ethers.getSigners();

  const guardian = signers[1];

  await deploy("CashKYCSenderFactory", {
    from: deployer,
    args: [guardian.address],
    log: true,
  });

  const kycRegistry = await ethers.getContract("KYCRegistry");

  // Deploy CashKYCSender from factory contract
  const factory = await ethers.getContract("CashKYCSenderFactory");
  await factory
    .connect(guardian)
    .deployCashKYCSender(
      "Cash-KYC-Sender",
      "CASH-KYC-S",
      kycRegistry.address,
      KYC_GROUP
    );

  // Get proxy and proxyAdmin addresses
  const cashKYCSenderProxyAddress = await factory.cashKYCSenderProxy();
  const cashKYCSenderProxyAdminAddress =
    await factory.cashKYCSenderProxyAdmin();

  // Save CashKYCSender Token to deployments
  const artifact = await deployments.getExtendedArtifact("CashKYCSender");
  let cashKYCSenderProxied = {
    address: cashKYCSenderProxyAddress,
    ...artifact,
  };
  await save("CashKYCSender", cashKYCSenderProxied);

  // Save Cash Proxy Admin to deployments
  const proxyAdminArtifact = await deployments.getExtendedArtifact(
    "ProxyAdmin"
  );
  let cashKYCSenderProxyAdmin = {
    address: cashKYCSenderProxyAdminAddress,
    ...proxyAdminArtifact,
  };
  await save("ProxyAdminCashKYCSender", cashKYCSenderProxyAdmin);

  const implementationAddress = await getImplementationAddress(
    ethers.provider,
    cashKYCSenderProxied.address
  );
  console.log("CashKYCSender Proxy is: ", cashKYCSenderProxyAddress);
  console.log("CashKYCSender Implementation is: ", implementationAddress);
  console.log("CashKYCSender ProxyAdmin is: ", cashKYCSenderProxyAdminAddress);
};

export default deployCashKYCSender;
deployCashKYCSender.tags = ["CashKYCSender", "Local"];
deployCashKYCSender.dependencies = ["KYCRegistry"];
