import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import glob

# Step 1: Load and clean latency logs
log_files = sorted(glob.glob("latency_*.log"))
throughput_data = {}
avg_throughput = {}

for filepath in log_files:
    label = os.path.splitext(os.path.basename(filepath))[0].split("_")[1]  # Extract delay label
    timestamps = []

    with open(filepath, "r") as f:
        for line in f:
            if "," not in line:
                continue
            parts = line.strip().split(",")
            if len(parts) < 2:
                continue
            ts_part = parts[0]
            if ts_part.isdigit():
                timestamps.append(int(ts_part) // 1000)  # Convert to seconds

    if timestamps:
        df = pd.Series(timestamps).value_counts().sort_index()
        throughput_data[label] = df
        avg_throughput[label] = df.mean()

# Step 2: Plot Throughput vs Time (cleaned and smoothed)
plt.figure(figsize=(12, 6))
for label, series in sorted(throughput_data.items()):
    # Interpolate missing seconds
    full_range = pd.Series(0, index=range(series.index.min(), series.index.max() + 1))
    full_range.update(series)
    smooth = full_range.rolling(window=3, center=True).mean()
    plt.plot(smooth.index - smooth.index.min(), smooth.values, label=label)

plt.xlabel("Time (seconds)", fontsize=12)
plt.ylabel("Throughput (ops/sec)", fontsize=12)
plt.title("Slow Leader: Throughput vs Time", fontsize=14)
plt.legend(title="Injected Delay")
plt.grid(True, linestyle="--", alpha=0.5)
plt.tight_layout()
plt.show()

# Step 3: Plot Degradation vs Delay (bar chart)
baseline = avg_throughput.get("0ms") or avg_throughput.get("baseline") or max(avg_throughput.values())
degradation = {label: 100 * (baseline - avg) / baseline for label, avg in avg_throughput.items() if label not in ["0ms", "baseline"]}

plt.figure(figsize=(8, 5))
labels = sorted(degradation.keys(), key=lambda x: int(x.replace("ms", "")))
values = [degradation[k] for k in labels]
bars = plt.bar(labels, values, color='steelblue')

plt.xlabel("Injected Delay", fontsize=12)
plt.ylabel("Throughput Degradation (%)", fontsize=12)
plt.title("Slow Leader: Performance Degradation vs Delay", fontsize=14)
plt.grid(axis='y', linestyle='--', alpha=0.6)
plt.ylim(0, max(values) + 10)
plt.tight_layout()
plt.show()
