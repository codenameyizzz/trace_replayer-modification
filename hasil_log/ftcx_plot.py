import matplotlib.pyplot as plt
import numpy as np
import os

def load_latencies(path, latency_cap=None):
    latencies = []
    with open(path, 'r') as f:
        for line in f:
            fields = line.strip().split(',')
            if len(fields) >= 2:
                try:
                    l = float(fields[1])
                    if latency_cap is None or l <= latency_cap:
                        latencies.append(l)
                except ValueError:
                    continue
    return latencies

# === Konfigurasi direktori dan file ===
log_dir = r"D:\Repo\hasil_log"  # Ganti dengan lokasi log lokal kamu

# List file sweep hasil FTCX berdasarkan injection probability
log_files = [
    "baseline_10k.log",
    "trace_ftcx_INJECT_PCT5.log",
    "trace_ftcx_INJECT_PCT10.log",
    "trace_ftcx_INJECT_PCT15.log",
    "trace_ftcx_INJECT_PCT20.log",
    "trace_ftcx_INJECT_PCT25.log",
    "trace_ftcx_INJECT_PCT30.log"
]

labels = {
    "baseline_10k.log": "Baseline",
    "trace_ftcx_INJECT_PCT5.log": "P=5%",
    "trace_ftcx_INJECT_PCT10.log": "P=10%",
    "trace_ftcx_INJECT_PCT15.log": "P=15%",
    "trace_ftcx_INJECT_PCT20.log": "P=20%",
    "trace_ftcx_INJECT_PCT25.log": "P=25%",
    "trace_ftcx_INJECT_PCT30.log": "P=30%",
}

latency_cap = None  # Bisa di-set ke misalnya 100000 untuk membatasi outlier

plt.figure(figsize=(12, 6))

for file in log_files:
    full_path = os.path.join(log_dir, file)
    latencies = load_latencies(full_path, latency_cap)
    if not latencies:
        print(f"⚠️  Warning: no latencies found in {file}")
        continue
    latencies = np.array(latencies)
    latencies.sort()
    cdf = np.arange(len(latencies)) / len(latencies)
    plt.plot(latencies, cdf * 100, label=labels.get(file, file), linewidth=1.3)

plt.xscale("log")
plt.xlabel("Latency (µs, log scale)")
plt.ylabel("CDF (%)")
plt.title("Latency CDF vs Injection Probability (FTCX)")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("latency_cdf_ftcx_sweep.png", dpi=300)
plt.show()
