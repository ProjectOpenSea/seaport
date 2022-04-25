import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";

import base from "../hardhat.config";

// This config file is for hardhat-deploy specific overrides

const config: HardhatUserConfig = {
  ...base,
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      accounts: {
        mnemonic:
          "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat",
      },
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    alice: {
      default: 1,
    },
    bob: {
      default: 2,
    },
  },
  paths: {
    root: "..",
    ...base.paths,
    deploy: "ops/deploy",
  },
};

export default config;
