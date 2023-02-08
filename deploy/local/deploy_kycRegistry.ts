import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { SANCTIONS_ORACLE } from "../production/constants";
const { ethers } = require("hardhat");

const deployKYCRegistry: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;
  const signers = await ethers.getSigners();

  const guardian = signers[1];

  // Note that using SANCTIONS_ORACLE places a constraint on fork block number.
  // The SANCTIONS contract must be deployed and in desired state at time of fork.
  await deploy("KYCRegistry", {
    from: deployer,
    args: [guardian.address, SANCTIONS_ORACLE],
    log: true,
  });
};

export default deployKYCRegistry;
deployKYCRegistry.tags = ["KYCRegistry", "Local"];
