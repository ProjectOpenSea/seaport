import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
import { subtask, task } from "hardhat/config";

import { compareLastTwoReports } from "./scripts/compare_reports";
import { printLastReport } from "./scripts/print_report";
import { getReportPathForCommit } from "./scripts/utils";
import { writeReports } from "./scripts/write_reports";

import type { HardhatUserConfig } from "hardhat/config";

import "dotenv/config";
import "@nomiclabs/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

// Filter Reference Contracts
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(
  async (_, __, runSuper) => {
    const paths = await runSuper();

    return paths.filter((p: any) => !p.includes("contracts/reference/"));
  }
);

task("write-reports", "Write pending gas reports").setAction(
  async (taskArgs, hre) => {
    writeReports(hre);
  }
);

task("compare-reports", "Compare last two gas reports").setAction(
  async (taskArgs, hre) => {
    compareLastTwoReports(hre);
  }
);

task("print-report", "Print the last gas report").setAction(
  async (taskArgs, hre) => {
    printLastReport(hre);
  }
);

const optimizerSettingsNoSpecializer = {
  enabled: true,
  runs: 4_294_967_295,
  details: {
    peephole: true,
    inliner: true,
    jumpdestRemover: true,
    orderLiterals: true,
    deduplicate: true,
    cse: true,
    constantOptimizer: true,
    yulDetails: {
      stackAllocation: true,
      optimizerSteps:
        "dhfoDgvulfnTUtnIf[xa[r]EscLMcCTUtTOntnfDIulLculVcul [j]Tpeulxa[rul]xa[r]cLgvifCTUca[r]LSsTOtfDnca[r]Iulc]jmul[jul] VcTOcul jmul",
    },
  },
};

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          viaIR: true,
          optimizer: {
            ...(process.env.NO_SPECIALIZER
              ? optimizerSettingsNoSpecializer
              : { enabled: true, runs: 16_200 }),
          },
          metadata: {
            bytecodeHash: "none",
          },
          outputSelection: {
            "*": {
              "*": ["evm.assembly", "irOptimized", "devdoc"],
            },
          },
        },
      },
    ],
    overrides: {
      "contracts/conduit/Conduit.sol": {
        version: "0.8.14",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 1000000,
          },
        },
      },
      "contracts/conduit/ConduitController.sol": {
        version: "0.8.14",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 1000000,
          },
        },
      },
      "contracts/helper/TransferHelper.sol": {
        version: "0.8.14",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 1000000,
          },
        },
      },
    },
  },
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      throwOnCallFailures: false,
      allowUnlimitedContractSize: true,
    },
    verificationNetwork: {
      url: process.env.NETWORK_RPC ?? "",
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    outputFile: getReportPathForCommit(),
    noColors: true,
  },
  etherscan: {
    apiKey: process.env.EXPLORER_API_KEY,
  },
  // specify separate cache for hardhat, since it could possibly conflict with foundry's
  paths: { cache: "hh-cache" },
};

export default config;
