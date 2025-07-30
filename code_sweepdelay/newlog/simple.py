import re
import matplotlib.pyplot as plt

# File lokal
files = {
    "1ms": "stress-output_1ms.log",
    "10ms": "stress-output10.log",
    "20ms": "stress-output20.log",
    "50ms": "stress-output50.log",
    "75ms": "stress-output75.log",
    "100ms": "stress-output100.log",
}

# Fungsi parsing latency & throughput per detik
def parse_log(filepath):
    seconds, ops, mean_lat = [], [], []
    with open(filepath, "r") as f:
        second = 0
        for line in f:
            match = re.match(
                r"total,\s+\d+,\s+([\d.]+),\s+\d+,\s+\d+,\s+([\d.]+),",
                line
            )
            if match:
                ops.append(float(match.group(1)))
                mean_lat.append(float(match.group(2)))
                seconds.append(second)
                second += 1
    return seconds, ops, mean_lat

# Parse kedua file
data = {label: parse_log(path) for label, path in files.items()}

# Plot
fig, axs = plt.subplots(2, 1, figsize=(10, 6), sharex=True)

# Latency
for label in data:
    seconds, _, lat = data[label]
    axs[0].plot(seconds, lat, label=f"{label} latency")

axs[0].set_ylabel("Latency (ms)")
axs[0].set_title("Latency Comparison")
axs[0].legend()
axs[0].grid(True, linestyle="--", alpha=0.6)

# Throughput
for label in data:
    seconds, ops, _ = data[label]
    axs[1].plot(seconds, ops, label=f"{label} throughput")

axs[1].set_xlabel("Time (s)")
axs[1].set_ylabel("Ops/sec")
axs[1].set_title("Throughput Comparison")
axs[1].legend()
axs[1].grid(True, linestyle="--", alpha=0.6)

plt.tight_layout()
plt.savefig("latency_throughput_comparison.png")
plt.show()
