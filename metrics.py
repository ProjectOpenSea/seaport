#! /usr/bin/env python

from collections import Counter
from matplotlib import pyplot as plt

def plot_metrics():
    counter = Counter()

    with open("metrics.txt", 'r') as metrics_file:
        for line in metrics_file:
            metric, _ = line.split("|")
            call, _ = metric.split(":")
            counter.update([call])

    plt.rcParams["figure.figsize"] = (20, 10)
    fig, ax = plt.subplots()
    bars = plt.bar(counter.keys(), counter.values())
    ax.bar_label(bars)
    plt.xticks(rotation=45)
    plt.show()

if __name__ == "__main__":
    plot_metrics()
