import os
import numpy as np
import matplotlib.pyplot as plt

def load_latencies(path, latency_cap=None):
    latencies = []
    with open(path, 'r') as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.strip().split(',')
            if len(parts) < 2:
                continue
            try:
                latency = float(parts[1])
                if latency_cap is None or latency <= latency_cap:
                    latencies.append(latency)
            except ValueError:
                continue
    return latencies

# === Konfigurasi direktori log ===
log_dir = r"D:\Repo\test_osfn"  # Ganti sesuai direktori log kamu

# === Daftar log termasuk baseline ===
log_files = [
    "baseline_10k.log",
    "trace_fsdelay_GCINT10_BURST100_DELAY500.log",
    "trace_fsdelay_GCINT10_BURST100_DELAY1000.log",
    "trace_fsdelay_GCINT10_BURST100_DELAY1500.log",
    "trace_fsdelay_GCINT10_BURST100_DELAY2000.log",
    "trace_fsdelay_GCINT10_BURST100_DELAY2500.log",
]

labels = {
    "baseline_10k.log": "Baseline",
    "trace_fsdelay_GCINT10_BURST100_DELAY500.log": "Delay=500µs",
    "trace_fsdelay_GCINT10_BURST100_DELAY1000.log": "Delay=1000µs",
    "trace_fsdelay_GCINT10_BURST100_DELAY1500.log": "Delay=1500µs",
    "trace_fsdelay_GCINT10_BURST100_DELAY2000.log": "Delay=2000µs",
    "trace_fsdelay_GCINT10_BURST100_DELAY2500.log": "Delay=2500µs",
}

latency_cap = None  # atau bisa di-set ke misalnya 100000

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
    plt.plot(latencies, cdf * 100, label=labels.get(file, file), linewidth=1.5)

plt.xscale("log")
plt.xlabel("Latency (µs, log scale)")
plt.ylabel("CDF (%)")
plt.title("Filesystem Delay CDF per Configuration (with Baseline)")
plt.grid(True, which="both", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("cdf_fsdelay_with_baseline.png", dpi=300)
plt.show()
