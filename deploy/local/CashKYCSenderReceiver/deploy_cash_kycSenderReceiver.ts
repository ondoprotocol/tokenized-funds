import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { BigNumber } from "ethers";
import { KYC_GROUP } from "./constants";
const { ethers } = require("hardhat");

const deployCashKYCSenderReceiver: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { save } = deployments;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;
  const signers = await ethers.getSigners();

  const guardian = signers[1];

  await deploy("CashKYCSenderReceiverFactory", {
    from: deployer,
    args: [guardian.address],
    log: true,
  });

  const kycRegistry = await ethers.getContract("KYCRegistry");

  // Deploy CashKYCSenderReceiver from the factory contract
  const factory = await ethers.getContract("CashKYCSenderReceiverFactory");
  await factory
    .connect(guardian)
    .deployCashKYCSenderReceiver(
      "Cash-KYC-SenderReciever",
      "CASH-KYC-SR",
      kycRegistry.address,
      KYC_GROUP
    );

  // Get proxy and proxyAdmin addresses
  const cashKYCSenderReceiverProxyAddress =
    await factory.cashKYCSenderReceiverProxy();
  const cashKYCSenderReceiverProxyAdminAddress =
    await factory.cashKYCSenderReceiverProxyAdmin();

  // Save CashKYCSenderReceiver Token to deployments
  const artifact = await deployments.getExtendedArtifact(
    "CashKYCSenderReceiver"
  );
  let cashKYCSenderReceiverProxied = {
    address: cashKYCSenderReceiverProxyAddress,
    ...artifact,
  };
  await save("CashKYCSenderReceiver", cashKYCSenderReceiverProxied);

  // Save Proxy Admin to deployments
  const proxyAdminArtifact = await deployments.getExtendedArtifact(
    "ProxyAdmin"
  );
  let cashKYCSenderRecieverProxyAdmin = {
    address: cashKYCSenderReceiverProxyAdminAddress,
    ...proxyAdminArtifact,
  };
  await save("ProxyAdminCashKYCSender", cashKYCSenderRecieverProxyAdmin);

  const implementationAddress = await getImplementationAddress(
    ethers.provider,
    cashKYCSenderReceiverProxied.address
  );
  console.log(
    "CashKYCSenderReceiver Proxy is: ",
    cashKYCSenderReceiverProxyAddress
  );
  console.log(
    "CashKYCSenderReceiver Implementation is: ",
    implementationAddress
  );
  console.log(
    "CashKYCSenderReceiver ProxyAdmin is: ",
    cashKYCSenderReceiverProxyAdminAddress
  );
};

export default deployCashKYCSenderReceiver;
deployCashKYCSenderReceiver.tags = ["CashKYCSenderReceiver", "Local"];
deployCashKYCSenderReceiver.dependencies = ["KYCRegistry"];
