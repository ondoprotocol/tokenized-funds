import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  PROD_GUARDIAN,
  PROD_ASSET_RECIPIENT,
  PROD_ASSET_SENDER,
  PROD_FEE_RECIPIENT,
  PROD_PAUSER,
  PROD_USDC_ADDRESS,
  KYC_GROUP_CASH,
  MINT_LIMIT,
  REDEEM_LIMIT,
  EPOCH_DURATION,
} from "../constants";

const deployCashManager: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts(); // Deployer is signers[0]
  const cashProxied = await ethers.getContract("Cash");
  const registry = await ethers.getContract("KYCRegistry");

  await deploy("CashManager", {
    from: deployer,
    args: [
      PROD_USDC_ADDRESS,
      cashProxied.address,
      PROD_GUARDIAN,
      PROD_PAUSER,
      PROD_ASSET_RECIPIENT,
      PROD_ASSET_SENDER,
      PROD_FEE_RECIPIENT,
      MINT_LIMIT,
      REDEEM_LIMIT,
      EPOCH_DURATION,
      registry.address,
      KYC_GROUP_CASH,
    ],
    log: true,
  });

  /**
   * Post Deployment:
   * 1) Grant Cash TRANSFER_ROLE + MINTER_ROLE to CashManager address
   */
};
export default deployCashManager;
deployCashManager.tags = ["Prod-Cash-CashManager", "Prod-Cash-2"];
