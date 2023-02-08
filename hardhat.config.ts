require("dotenv").config();
import { task, HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-contract-sizer";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: { mnemonic: process.env.MNEMONIC },
      forking: {
        url: process.env.ETHEREUM_RPC_URL!,
        blockNumber: parseInt(process.env.FORK_FROM_BLOCK_NUMBER!),
      },
      chainId: process.env.CHAIN_ID ? parseInt(process.env.CHAIN_ID) : 1337,
    },
    goerli: {
      accounts: [process.env.TESTNET_PRIVATE_KEY!],
      url: process.env.GOERLI_RPC_URL,
      gas: 5000000,
    },
    mainnet: {
      accounts: [process.env.MAINNET_PRIVATE_KEY!],
      url: process.env.ETHEREUM_RPC_URL!,
      gas: 6000000,
    },
    matic: {
      accounts: [process.env.MAINNET_PRIVATE_KEY!],
      url: process.env.POLYGON_RPC_URL!,
      gas: 6000000,
    },
  },
  mocha: {
    timeout: 60 * 30 * 1000,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  namedAccounts: {
    deployer: 0,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
  },
};

export default config;
