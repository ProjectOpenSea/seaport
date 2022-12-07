import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
import { subtask } from "hardhat/config";

import type { HardhatUserConfig } from "hardhat/config";

import "dotenv/config";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

// Filter Reference Contracts
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(
  async (_, __, runSuper) => {
    const paths = await runSuper();

    return paths.filter(
      (p: any) =>
        !p.endsWith("/Consideration.sol") && !p.includes("contracts/lib/")
    );
  }
);

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.8",
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
      allowUnlimitedContractSize: true,
      throwOnCallFailures: false,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  // specify separate cache for hardhat, since it could possibly conflict with foundry's
  paths: {
    sources: "./reference",
    cache: "hh-cache-ref",
    artifacts: "./artifacts-ref",
  },
};

export default config;
