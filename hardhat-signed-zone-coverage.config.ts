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
        version: "0.8.17",
        settings: {
          viaIR: false,
          optimizer: {
            enabled: false,
          },
        },
      },
      {
        version: "0.8.19",
        settings: {
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
      blockGasLimit: 30_000_000,
      throwOnCallFailures: false,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  paths: {
    sources: "./signed-zone",
    cache: "hh-cache-signed-zone",
    artifacts: "./artifacts-signed-zone",
    tests: "./signed-zone/test",
  },
};

export default config;
