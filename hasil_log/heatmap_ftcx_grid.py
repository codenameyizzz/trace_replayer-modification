import os
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt

def extract_avg_latency(log_path):
    latencies = []
    with open(log_path, 'r') as f:
        for line in f:
            fields = line.strip().split(',')
            if len(fields) >= 2:
                try:
                    lat = float(fields[1])
                    latencies.append(lat)
                except ValueError:
                    continue
    if latencies:
        return np.mean(latencies)
    else:
        return None

# === Konfigurasi ===
log_dir = r"D:\Repo\hasil_log"  # ← ubah sesuai lokasi hasil .log kamu

# Sweep values
inject_pcts = [5, 10, 15, 20, 25, 30]
delay_max_us = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]

# Buat matrix kosong
heatmap_matrix = np.zeros((len(inject_pcts), len(delay_max_us)))

# Isi matrix
for i, p in enumerate(inject_pcts):
    for j, d in enumerate(delay_max_us):
        fname = f"trace_ftcx_P{p}_D{d}.log"
        path = os.path.join(log_dir, fname)
        if os.path.exists(path):
            avg_lat = extract_avg_latency(path)
            heatmap_matrix[i, j] = avg_lat if avg_lat else 0
        else:
            print(f"File missing: {fname}")
            heatmap_matrix[i, j] = np.nan  # Beri NaN jika file tidak ada

# === Plotting ===
plt.figure(figsize=(12, 6))
sns.heatmap(
    heatmap_matrix,
    annot=True,
    fmt=".0f",
    xticklabels=delay_max_us,
    yticklabels=[f"{p}%" for p in inject_pcts],
    cmap="viridis"
)

plt.xlabel("Max Delay per I/O (µs)")
plt.ylabel("Injection Probability")
plt.title("Average Latency Heatmap (FTCX Fault Injection)")
plt.tight_layout()
plt.savefig("heatmap_ftcx_avg_latency.png", dpi=300)
plt.show()
