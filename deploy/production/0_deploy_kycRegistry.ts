import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { PROD_GUARDIAN, SANCTIONS_ORACLE } from "./constants";

const deployKYCRegistry: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  await deploy("KYCRegistry", {
    from: deployer,
    args: [PROD_GUARDIAN, SANCTIONS_ORACLE],
    log: true,
  });
};

export default deployKYCRegistry;
deployKYCRegistry.tags = ["Prod-KYCRegistry", "Prod-0"];
