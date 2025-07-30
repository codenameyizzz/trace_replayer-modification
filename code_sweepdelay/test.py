import matplotlib.pyplot as plt
import numpy as np

# Mapping label → filepath
files = {
    "baseline": "latencies_ms_baseline.log",
    "50ms delay": "latencies_ms_50ms.log",
    "20ms delay": "latencies_ms_20ms.log"
}

plt.figure(figsize=(10, 6))

for label, filepath in files.items():
    with open(filepath, "r") as f:
        latencies = np.array([int(line.strip()) for line in f if line.strip().isdigit()])
        latencies_sorted = np.sort(latencies)
        cdf = np.arange(1, len(latencies_sorted)+1) / len(latencies_sorted)
        plt.plot(latencies_sorted, cdf, label=label)

plt.xlabel("Latency (ms)")
plt.ylabel("CDF")
plt.title("Latency CDF Comparison of ETCD PUT Operations")
plt.grid(True, linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("etcd_latency_cdf_comparison.png")
plt.show()
