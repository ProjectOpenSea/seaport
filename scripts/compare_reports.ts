import { diffPctString, toCommentTable } from "./comment-table";
import { printLastReport } from "./print_report";
import { getAllReports } from "./utils";
import { writeReports } from "./write_reports";

import type { ContractReport } from "./utils";
import type { HardhatRuntimeEnvironment } from "hardhat/types";

export function compareReports(
  oldReport: ContractReport,
  newReport: ContractReport
) {
  const rows: string[][] = [];
  rows.push([`method`, `min`, `max`, `avg`, `calls`]);
  oldReport.methods.forEach((r1, i) => {
    const r2 = newReport.methods[i];
    rows.push([
      r1.method,
      diffPctString(r2.min, r1.min, false, true),
      diffPctString(r2.max, r1.max, false, true),
      diffPctString(r2.avg, r1.avg, false, true),
      diffPctString(r2.calls, r1.calls, false, true),
    ]);
  });
  const { bytecodeSize: initSize1, deployedBytecodeSize: size1 } = oldReport;
  const { bytecodeSize: initSize2, deployedBytecodeSize: size2 } = newReport;
  rows.push([
    `runtime size`,
    diffPctString(size2, size1, false, true),
    "",
    "",
    "",
  ]);
  rows.push([
    `init code size`,
    diffPctString(initSize2, initSize1, false, true),
    "",
    "",
    "",
  ]);
  const table = toCommentTable(rows);
  const separator = table[0];
  table.splice(table.length - 3, 0, separator);
  console.log(table.join("\n"));
}

export function compareLastTwoReports(hre: HardhatRuntimeEnvironment) {
  writeReports(hre);
  const reports = getAllReports();
  if (reports.length === 1) {
    printLastReport(hre);
    return;
  }
  if (reports.length < 2) {
    return;
  }
  const [currentReport, previousReport] = reports;
  const contractName = "Seaport";
  compareReports(
    previousReport.contractReports[contractName],
    currentReport.contractReports[contractName]
  );
  const ts = Math.floor(Date.now() / 1000);
  const currentSuffix =
    currentReport.name !== currentReport.commitHash
      ? ` @ ${currentReport.commitHash}`
      : "";
  const previousSuffix =
    previousReport.name !== previousReport.commitHash
      ? ` @ ${previousReport.commitHash}`
      : "";
  console.log(
    `Current Report: ${+((currentReport.timestamp - ts) / 60).toFixed(
      2
    )} min ago (${currentReport.name})${currentSuffix}`
  );
  console.log(
    `Previous Report: ${+((previousReport.timestamp - ts) / 60).toFixed(
      2
    )} min ago (${previousReport.name})${previousSuffix}`
  );
}
