import fs from "fs";

import { getAllRawReports, getCommitHash } from "./utils";

import type { CommitGasReport, ContractReport } from "./utils";
import type { HardhatRuntimeEnvironment } from "hardhat/types";

export function writeReports(hre: HardhatRuntimeEnvironment): void {
  const rawReports = getAllRawReports();
  if (rawReports.length === 0) {
    return;
  }
  if (rawReports.length > 1) {
    throw Error(
      `Multiple pending reports. Can only process most recent report to obtain current contract sizes`
    );
  }
  const [rawReport] = rawReports;
  const contractReports: Record<string, ContractReport> = {};
  for (const { contract, ...report } of rawReport.report) {
    if (!contractReports[contract]) {
      const artifact = hre.artifacts.readArtifactSync(contract);
      const bytecode = Buffer.from(artifact.bytecode.slice(2), "hex");
      const deployedBytecode = Buffer.from(
        artifact.deployedBytecode.slice(2),
        "hex"
      );
      contractReports[contract] = {
        name: contract,
        methods: [],
        bytecodeSize: bytecode.byteLength,
        deployedBytecodeSize: deployedBytecode.byteLength,
      };
    }
    contractReports[contract].methods.push(report);
  }
  const report: CommitGasReport = {
    commitHash: getCommitHash(),
    contractReports,
  };
  fs.unlinkSync(rawReport.path);
  fs.writeFileSync(
    rawReport.path.replace(".md", ".json"),
    JSON.stringify(report, null, 2)
  );
}
