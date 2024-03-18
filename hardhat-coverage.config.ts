import type { HardhatUserConfig } from "hardhat/config";

import "dotenv/config";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          evmVersion: "cancun",
          viaIR: false,
          optimizer: {
            enabled: false,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      blockGasLimit: 300_000_000,
      throwOnCallFailures: false,
      allowUnlimitedContractSize: true,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
};

export default config;
