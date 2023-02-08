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
  KYC_GROUP_CASH_SENDER_RECEIVER,
} from "../constants";

const deployCashManager_CashKYCSenderReceiver: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts(); // Deployer is signers[0]

  const cashKYCSenderReceiverProxied = await ethers.getContract(
    "CashKYCSenderReceiver"
  );

  const registry = await ethers.getContract("KYCRegistry");

  await deploy("CashManager-CashKYCSenderReceiver", {
    from: deployer,
    contract: "CashManager",
    args: [
      PROD_USDC_ADDRESS,
      cashKYCSenderReceiverProxied.address,
      PROD_GUARDIAN,
      PROD_PAUSER,
      PROD_ASSET_RECIPIENT,
      PROD_ASSET_SENDER,
      PROD_FEE_RECIPIENT,
      MINT_LIMIT,
      REDEEM_LIMIT,
      EPOCH_DURATION,
      registry.address,
      KYC_GROUP_CASH_SENDER_RECEIVER,
    ],
    log: true,
  });

  /**
   * Post Deployment:
   * 1) Grant CashKYCSenderReceiver MINTER_ROLE to CashManager address
   * 2) Add CashManager-CashKYCSenderReceiver to KYCRegistry
   */
};
export default deployCashManager_CashKYCSenderReceiver;
deployCashManager_CashKYCSenderReceiver.tags = [
  "Prod-CashKYCSenderReceiver-CashManager",
  "Prod-CashKYCSenderReceiver-2",
];
