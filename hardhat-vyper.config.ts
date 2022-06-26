import * as dotenv from "dotenv";
import { HardhatUserConfig, subtask } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-vyper";

import { TASK_COMPILE_VYPER_RUN_BINARY } from "@nomiclabs/hardhat-vyper/dist/src/task-names";
import { compileHook } from "./vyper/scripts/vyper-hardhat-compile-hook";

dotenv.config();

// Preprocees and compile Vyper contracts.
subtask(TASK_COMPILE_VYPER_RUN_BINARY).setAction(compileHook);

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  vyper: {
    version: "0.3.4",
  },
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
    },
  },
  // specify separate cache for hardhat, since it could possibly conflict with foundry's
  paths: {
    artifacts: "./vyper/artifacts",
    sources: "./vyper/contracts",
  },
};

export default config;
