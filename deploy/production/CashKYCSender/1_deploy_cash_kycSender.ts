import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { PROD_GUARDIAN } from "../constants";

const deployCashKYCSenderFactory: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Deploy the CashKYCSender Factory contract
  await deploy("CashKYCSenderFactory", {
    from: deployer,
    args: [PROD_GUARDIAN],
    log: true,
  });

  /**
   * Post Deployment:
   * 1) Call deployCashKYCSender() on CashKYCSender Factory contract
   *    PLEASE BE AWARE: Match KYC_GROUP parameter with the KYC group in
   *    CashManager constructor
   */
};

export default deployCashKYCSenderFactory;
deployCashKYCSenderFactory.tags = [
  "Prod-CashKYCSenderFactory",
  "Prod-CashKYCSender-1",
];
