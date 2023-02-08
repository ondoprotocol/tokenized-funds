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
  EPOCH_DURATION,
  MINT_LIMIT,
  REDEEM_LIMIT,
  KYC_GROUP_CASH_SENDER,
} from "../constants";

const deployCashManager_CashKYCSender: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts(); // Deployer is signers[0]

  const cashKYCSenderProxied = await ethers.getContract("CashKYCSender");
  const registry = await ethers.getContract("KYCRegistry");

  await deploy("CashManager-CashKYCSender", {
    from: deployer,
    contract: "CashManager",
    args: [
      PROD_USDC_ADDRESS,
      cashKYCSenderProxied.address,
      PROD_GUARDIAN,
      PROD_PAUSER,
      PROD_ASSET_RECIPIENT,
      PROD_ASSET_SENDER,
      PROD_FEE_RECIPIENT,
      MINT_LIMIT,
      REDEEM_LIMIT,
      EPOCH_DURATION,
      registry.address,
      KYC_GROUP_CASH_SENDER,
    ],
    log: true,
  });

  /**
   * Post Deployment:
   * 1) Grant CashKYCSender MINTER_ROLE to CashManager address
   * 2) Add CashManager-CashKYCSender to KYCRegistry
   */
};
export default deployCashManager_CashKYCSender;
deployCashManager_CashKYCSender.tags = [
  "Prod-CashKYCSender-CashManager",
  "Prod-CashKYCSender-2",
];
