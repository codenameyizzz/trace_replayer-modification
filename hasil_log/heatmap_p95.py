import os
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt

def load_p95_latency(filepath):
    latencies = []
    with open(filepath, 'r') as f:
        for line in f:
            fields = line.strip().split(',')
            if len(fields) >= 2:
                try:
                    l = float(fields[1])
                    latencies.append(l)
                except ValueError:
                    continue
    if latencies:
        return round(np.percentile(latencies, 95), 2)
    return None

# === Konfigurasi parameter sweep ===
log_dir = r"D:\Repo\hasil_log"  # Ganti sesuai folder log kamu

probabilities = [5, 10, 15, 20, 25, 30]         # INJECT_PCT
delays = [1000 * i for i in range(1, 11)]       # DELAY_MAX_US: 1000 → 10000
matrix = []

for p in probabilities:
    row = []
    for d in delays:
        filename = f"trace_ftcx_P{p}_D{d}.log"  # Sesuaikan dengan penamaan sweep_grid_ftcx
        filepath = os.path.join(log_dir, filename)
        if os.path.exists(filepath):
            p95 = load_p95_latency(filepath)
            row.append(p95 if p95 is not None else np.nan)
        else:
            row.append(np.nan)
    matrix.append(row)

# === Plot heatmap ===
plt.figure(figsize=(12, 6))
ax = sns.heatmap(
    matrix,
    annot=True,
    fmt=".1f",
    xticklabels=[f"{d//1000}k" for d in delays],
    yticklabels=[f"{p}%" for p in probabilities],
    cmap="magma",
    linewidths=0.5,
    linecolor="gray"
)

plt.title("P95 Latency Heatmap (FTCX Fault Injection)")
plt.xlabel("Max Delay per I/O (µs)")
plt.ylabel("Injection Probability")
plt.tight_layout()
plt.savefig("heatmap_ftcx_p95.png", dpi=300)
plt.show()
