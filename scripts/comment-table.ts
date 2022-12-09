import chalk from "chalk";

export const err = chalk.bold.red;
export const warn = chalk.hex("#FFA500");
export const info = chalk.blue;
export const success = chalk.green;

export function diffPctString(
  newValue: number,
  oldValue: number,
  warnOnIncrease?: boolean,
  diffOnly?: boolean
): string {
  if (newValue === null && oldValue === null) {
    return warn("null");
  }
  const diff = newValue - oldValue;

  if (diff === 0) return info(newValue.toString());
  const pct = +((100 * diff) / oldValue).toFixed(2);
  const pctPrefix = pct > 0 ? "+" : "";
  const color = diff > 0 ? (warnOnIncrease ? warn : err) : success;
  const valuePrefix = diffOnly && diff > 0 ? "+" : "";
  const value = diffOnly ? diff : newValue;
  return `${valuePrefix}${value} (${color(`${pctPrefix}${pct}%`)})`;
}
// eslint-disable-next-line no-control-regex
const stripANSI = (str: string) => str.replace(/\u001b\[.*?m/g, "");

export function getColumnSizesAndAlignments(
  rows: string[][],
  padding = 0
): Array<[number, boolean]> {
  const sizesAndAlignments: Array<[number, boolean]> = [];
  const numColumns = rows[0].length;
  for (let i = 0; i < numColumns; i++) {
    const entries = rows.map((row) => stripANSI(row[i]));
    const maxSize = Math.max(...entries.map((e) => e.length));
    const alignLeft = entries
      .slice(1)
      .filter((e) => !e.includes("null"))
      .some((e) => !!e.match(/[a-zA-Z]/g));
    sizesAndAlignments.push([maxSize + padding, alignLeft]);
  }
  return sizesAndAlignments;
}

const padColumn = (
  col: string,
  size: number,
  padWith: string,
  alignLeft: boolean
) => {
  const padSize = Math.max(0, size - stripANSI(col).length);
  const padding = padWith.repeat(padSize);
  if (alignLeft) return `${col}${padding}`;
  return `${padding}${col}`;
};

export const toCommentTable = (rows: string[][]): string[] => {
  const sizesAndAlignments = getColumnSizesAndAlignments(rows);
  rows.forEach((row) => {
    row.forEach((col, c) => {
      const [size, alignLeft] = sizesAndAlignments[c];
      row[c] = padColumn(col, size, " ", alignLeft);
    });
  });

  const completeRows = rows.map((row) => `| ${row.join(" | ")} |`);
  const rowSeparator = `==${sizesAndAlignments
    .map(([size]) => "=".repeat(size))
    .join("===")}==`;
  completeRows.splice(1, 0, rowSeparator);
  completeRows.unshift(rowSeparator);
  completeRows.push(rowSeparator);
  return completeRows;
};
