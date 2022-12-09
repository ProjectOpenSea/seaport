import { err, toCommentTable, warn } from "./comment-table";
import { getAllReports } from "./utils";
import { writeReports } from "./write_reports";

import type { ContractReport } from "./utils";
import type { HardhatRuntimeEnvironment } from "hardhat/types";

export function printReport(report: ContractReport) {
  const rows: string[][] = [];
  rows.push([`method`, `min`, `max`, `avg`, `calls`]);
  report.methods.forEach(({ method, min, max, avg, calls }) => {
    rows.push([
      method,
      min?.toString() ?? warn("null"),
      max?.toString() ?? warn("null"),
      avg?.toString() ?? warn("null"),
      calls?.toString() ?? warn("null"),
    ]);
  });
  rows.push([
    `runtime size`,
    report.deployedBytecodeSize.toString(),
    "",
    "",
    "",
  ]);
  rows.push([`init code size`, report.bytecodeSize.toString(), "", "", ""]);
  const table = toCommentTable(rows);
  const separator = table[0];
  table.splice(table.length - 3, 0, separator);
  console.log(table.join("\n"));
}

export function printLastReport(hre: HardhatRuntimeEnvironment) {
  writeReports(hre);
  const reports = getAllReports();
  if (reports.length < 1) {
    console.log(err(`No gas reports found`));
    return;
  }
  const contractName = "Seaport";
  const [currentReport] = reports;
  printReport(currentReport.contractReports[contractName]);
  const ts = Math.floor(Date.now() / 1000);
  const suffix =
    currentReport.name !== currentReport.commitHash
      ? ` @ ${currentReport.commitHash}`
      : "";
  console.log(
    `Current Report: ${+((currentReport.timestamp - ts) / 60).toFixed(
      2
    )} min ago (${currentReport.name}) ${suffix}`
  );
}
