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
                    latency = float(fields[1])
                    if latency_cap is None or latency <= latency_cap:
                        latencies.append(latency)
                except ValueError:
                    continue
    return latencies

# === Ubah sesuai lokasi folder log kamu ===
log_dir = r"D:\Repo\hasil_log"

# === Nama file log yang akan dibandingkan ===
log_files = {
    "Baseline (no fault)": "baseline_raid_10k.log",
    "RAID delay 20ms (offset 8.5–8.7GB)": "trace_raid_delay20_start8500000000_end8700000000.log"
}

plt.figure(figsize=(10, 6))

for label, filename in log_files.items():
    full_path = os.path.join(log_dir, filename)
    latencies = load_latencies(full_path)
    if not latencies:
        print(f" Warning: No latencies loaded from {filename}")
        continue

    latencies = np.array(latencies)
    latencies.sort()
    cdf = np.arange(len(latencies)) / len(latencies)

    plt.plot(latencies, cdf * 100, label=label, linewidth=1.6)

plt.xscale("log")
plt.xlabel("Latency (µs, log scale)")
plt.ylabel("CDF (%)")
plt.title("Latency CDF: Baseline vs RAID Tail Fault Injection")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("cdf_raid_tail_vs_baseline.png", dpi=300)
plt.show()
