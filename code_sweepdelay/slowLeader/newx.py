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

# Step 2 and 3: Create subplots (side-by-side)
fig, axs = plt.subplots(1, 2, figsize=(14, 5))

# Throughput vs Time (smoothed)
for label, series in sorted(throughput_data.items()):
    full_range = pd.Series(0, index=range(series.index.min(), series.index.max() + 1))
    full_range.update(series)
    smooth = full_range.rolling(window=3, center=True).mean()
    axs[0].plot(smooth.index - smooth.index.min(), smooth.values, label=label)

axs[0].set_title("Throughput vs Time", fontsize=13)
axs[0].set_xlabel("Time (seconds)")
axs[0].set_ylabel("Throughput (ops/sec)")
axs[0].legend(title="Delay")
axs[0].grid(True, linestyle="--", alpha=0.5)

# Performance Degradation vs Delay
baseline = avg_throughput.get("0ms") or avg_throughput.get("baseline") or max(avg_throughput.values())
degradation = {label: 100 * (baseline - avg) / baseline for label, avg in avg_throughput.items() if label not in ["0ms", "baseline"]}
labels = sorted(degradation.keys(), key=lambda x: int(x.replace("ms", "")))
values = [degradation[k] for k in labels]
axs[1].bar(labels, values, color='steelblue')
axs[1].set_title("Performance Degradation vs Delay", fontsize=13)
axs[1].set_xlabel("Injected Delay")
axs[1].set_ylabel("Throughput Degradation (%)")
axs[1].set_ylim(0, max(values) + 10)
axs[1].grid(axis='y', linestyle='--', alpha=0.6)

plt.tight_layout()
plt.show()
