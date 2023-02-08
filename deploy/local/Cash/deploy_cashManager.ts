import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { parseUnits } from "ethers/lib/utils";

import {
  USDC_ADDRESS,
  TRANSFER_ROLE,
  MINTER_ROLE,
} from "../../../test/util/constants";
import { KYC_GROUP } from "./constants";
import { BigNumber } from "ethers";

const deployCashManager: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts(); // Deployer is signers[0]
  const signers = await ethers.getSigners();

  const guardian = signers[1];
  const pauser = signers[2];
  const assetRecipient = signers[3];
  const feeRecipient = signers[4];
  const assetSender = signers[5];

  const cashProxiedContract = await ethers.getContract("Cash");

  const registry = await ethers.getContract("KYCRegistry");

  await deploy("CashManager", {
    from: deployer,

    args: [
      USDC_ADDRESS,
      cashProxiedContract.address,
      guardian.address,
      pauser.address,
      assetRecipient.address,
      assetSender.address,
      feeRecipient.address,
      parseUnits("10000", 6), // mint limit
      parseUnits("10000", 18), // redeem limit
      BigNumber.from(86400), // epoch duration seconds
      registry.address, // KYC registry
      KYC_GROUP,
    ],
    log: true,
  });
  const cashManagerContract = await ethers.getContract("CashManager");
  await cashProxiedContract
    .connect(guardian)
    .grantRole(TRANSFER_ROLE, cashManagerContract.address);
  await cashProxiedContract
    .connect(guardian)
    .grantRole(MINTER_ROLE, cashManagerContract.address);
};
export default deployCashManager;
deployCashManager.tags = ["CashManager-Cash", "Local"];
deployCashManager.dependencies = ["Cash", "KYCRegistry"];
