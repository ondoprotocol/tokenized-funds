import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { PROD_GUARDIAN } from "../constants";

const deployCashFactory: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Deploy the CashFactory contract
  await deploy("CashFactory", {
    from: deployer,
    args: [PROD_GUARDIAN],
    log: true,
  });

  /**
   * Post Deployment:
   * 1) Call deployCash() on CashFactory contract
   */
};

export default deployCashFactory;
deployCashFactory.tags = ["Prod-CashFactory", "Prod-Cash-1"];
