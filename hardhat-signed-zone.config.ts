import type { HardhatUserConfig } from "hardhat/config";

import "dotenv/config";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

// Use a default test pk if we do not have one in our .env - DO NOT USE THIS IN PRODUCTION
const deployerPk =
  process.env.DEPLOYER_PK ??
  "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad";

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
              : { enabled: true, runs: 4_294_967_295 }),
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
      {
        version: "0.8.19",
        settings: {
          viaIR: true,
          optimizer: {
            ...(process.env.NO_SPECIALIZER
              ? optimizerSettingsNoSpecializer
              : { enabled: true, runs: 9999999 }),
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
  },
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      throwOnCallFailures: false,
      allowUnlimitedContractSize: false,
    },
    verificationNetwork: {
      url: process.env.NETWORK_RPC ?? "",
    },
    mainnet: {
      url: process.env.ETHEREUM_RPC_URL ?? "",
      accounts: [deployerPk],
    },
    goerli: {
      url: process.env.GOERLI_RPC_URL ?? "",
      accounts: [deployerPk],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    noColors: true,
  },
  etherscan: {
    apiKey: process.env.EXPLORER_API_KEY,
  },
  // specify separate cache for hardhat, since it could possibly conflict with foundry's
  paths: {
    sources: "./signed-zone",
    cache: "hh-cache-signed-zone",
    artifacts: "./artifacts-signed-zone",
    tests: "./signed-zone/test",
  },
};

export default config;
