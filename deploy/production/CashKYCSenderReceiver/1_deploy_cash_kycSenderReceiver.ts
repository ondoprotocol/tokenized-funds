import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { PROD_GUARDIAN } from "../constants";

const deployCashKYCSenderReceiverFactory: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Deploy the CashKYCSenderReceiver Factory contract
  await deploy("CashKYCSenderReceiverFactory", {
    from: deployer,
    args: [PROD_GUARDIAN],
    log: true,
  });

  /**
   * Post Deployment:
   * 1) Call deployCashKYCSenderReceiver() on CashKYCSenderReceiver Factory
   *    contract
   *    PLEASE BE AWARE: Match KYC_GROUP parameter with the KYC group in
   *    Cash Manager constructor
   */
};

export default deployCashKYCSenderReceiverFactory;
deployCashKYCSenderReceiverFactory.tags = [
  "Prod-CashKYCSenderReceiverFactory",
  "Prod-CashKYCSenderReceiver-1",
];
