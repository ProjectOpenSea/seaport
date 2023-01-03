import fs from "fs";
import path from "path";

import { diffPctString, toCommentTable } from "./comment-table";

type GasReport = {
  contract: string;
  method: string;
  min: number;
  max: number;
  avg: number;
  calls: number;
};

function parseReport(text: string): GasReport[] {
  const lines = text
    .split("\n")
    .slice(6)
    .filter((ln) => ln.indexOf("·") !== 0);
  const rows = lines
    .map((ln) => ln.replace(/\|/g, "").replace(/\s/g, "").split("·"))
    .filter((row) => row.length === 7)
    .map(([contract, method, min, max, avg, calls]) => ({
      contract,
      method,
      min: +min,
      max: +max,
      avg: +avg,
      calls: +calls,
    }));
  return rows;
}

function parseReportFile(fileName: string, write?: boolean) {
  const text = fs.readFileSync(path.join(__dirname, fileName), "utf8");
  const report = parseReport(text);
  if (write) {
    fs.writeFileSync(
      path.join(__dirname, fileName.replace(".md", ".json")),
      JSON.stringify(report, null, 2)
    );
  }
  return report;
}

export function compareReports(report1: GasReport[], report2: GasReport[]) {
  const rows: string[][] = [];
  rows.push([`contract`, `method`, `min`, `max`, `avg`]);
  report1.forEach((r1, i) => {
    if (r1.contract !== "Seaport") return;
    const r2 = report2[i];
    if (r1.contract !== r2.contract || r1.method !== r2.method) {
      throw new Error("contract and method for comparison do not match");
    }
    rows.push([
      r1.contract,
      r1.method,
      diffPctString(r2.min, r1.min, false, true),
      diffPctString(r2.max, r1.max, false, true),
      diffPctString(r2.avg, r1.avg, false, true),
    ]);
  });
  console.log(toCommentTable(rows).join("\n"));
}

export function compareReportFiles(
  name1: string,
  name2: string,
  write?: boolean
) {
  const report1 = parseReportFile(name1, write);
  const report2 = parseReportFile(name2, write);
  compareReports(report1, report2);
}
