import { execSync } from "child_process";
import fs from "fs";
import path from "path";

export const GAS_REPORTS_DIR = path.join(__dirname, "../.gas_reports");

if (!fs.existsSync(GAS_REPORTS_DIR)) {
  fs.mkdirSync(GAS_REPORTS_DIR);
}

export type RawMethodReport = {
  contract: string;
  method: string;
  min: number;
  max: number;
  avg: number;
  calls: number;
};

export type RawGasReport = {
  name: string;
  path: string;
  timestamp: number;
  report: RawMethodReport[];
};

export type MethodReport = {
  method: string;
  min: number;
  max: number;
  avg: number;
  calls: number;
};

export type ContractReport = {
  name: string;
  deployedBytecodeSize: number;
  bytecodeSize: number;
  methods: MethodReport[];
};

export type CommitGasReport = {
  commitHash: string;
  contractReports: Record<string, ContractReport>;
};

export function getCommitHash() {
  return execSync("git rev-parse HEAD").toString().trim();
}

export function getReportPathForCommit(commit?: string): string {
  if (!commit) {
    commit = getCommitHash();
  }
  return path.join(GAS_REPORTS_DIR, `${commit}.md`);
}

export function haveReportForCurrentCommit(): boolean {
  return fs.existsSync(getReportPathForCommit());
}

export function fileLastUpdate(filePath: string): number {
  let timestamp = parseInt(
    execSync(`git log -1 --pretty="format:%ct" ${filePath}`)
      .toString()
      .trim() || "0"
  );
  if (!timestamp) {
    timestamp = Math.floor(+fs.statSync(filePath).mtime / 1000);
  }
  return timestamp;
}

function parseRawReport(text: string): RawMethodReport[] {
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

export function getAllRawReports(): RawGasReport[] {
  const reports = fs
    .readdirSync(GAS_REPORTS_DIR)
    .filter((file) => path.extname(file) === ".md")
    .map((file) => {
      const reportPath = path.join(GAS_REPORTS_DIR, file);
      const timestamp = fileLastUpdate(reportPath);
      const text = fs.readFileSync(reportPath, "utf8");
      const report = parseRawReport(text);
      return {
        name: path.parse(file).name,
        path: reportPath,
        timestamp,
        report,
      };
    });

  reports.sort((a, b) => b.timestamp - a.timestamp);
  return reports;
}

export function getAllReports(): (CommitGasReport & {
  name: string;
  path: string;
  timestamp: number;
})[] {
  const reports = fs
    .readdirSync(GAS_REPORTS_DIR)
    .filter((file) => path.extname(file) === ".json")
    .map((file) => {
      const reportPath = path.join(GAS_REPORTS_DIR, file);
      const timestamp = fileLastUpdate(reportPath);
      const report = require(reportPath) as CommitGasReport;
      return {
        name: path.parse(file).name,
        path: reportPath,
        timestamp,
        ...report,
      };
    });

  reports.sort((a, b) => b.timestamp - a.timestamp);
  return reports;
}
