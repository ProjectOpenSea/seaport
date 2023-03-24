import barChart from "cli-barchart";
import fs from "fs";

function plotMetrics() {
  const counter = new Map<string, number>();

  const metricsData = fs.readFileSync("metrics.txt", "utf-8");
  const lines = metricsData.split("\n");

  for (const line of lines) {
    if (line.trim() === "") continue;
    const [metric] = line.split("|");
    const [call] = metric.split(":");

    counter.set(call, (counter.get(call) ?? 0) + 1);
  }

  const data = Array.from(counter.entries()).map(([key, value]) => ({
    key,
    value,
  }));
  const totalRuns = data.reduce((acc, item) => acc + item.value, 0);

  type Item = { key: string; value: number };
  const renderLabel = (_item: Item, index: number) => {
    const percent = ((data[index].value / totalRuns) * 100).toFixed(2);
    return `${data[index].value.toString()} (${percent}%)`;
  };

  const options = {
    renderLabel,
  };

  const chart = barChart(data, options);
  console.log(`Fuzz test metrics (${totalRuns} runs):\n`);
  console.log(chart);
}

plotMetrics();
