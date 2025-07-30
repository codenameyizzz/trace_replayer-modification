import re
import matplotlib.pyplot as plt

# Updated file mapping after code reset
files = {
    "baseline": "stress-output_baseline.txt",
    "1ms" : "stress-output_1ms_90.log",
    "2ms": "stress-output_2ms_90.log",
    "5ms": "stress-output_5ms_90.log",
    "10ms": "stress-output_10ms_90.log",
    "25ms": "stress-output_25ms_90.log",
    "50ms": "stress-output_50ms_90.log",
    "75ms": "stress-output_75ms_90.log",
    "100ms": "stress-output_100ms_90.log",
    "1000ms": "stress-output_1000ms_90.log"
}

# Function to parse logs
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

# Parse all files
data = {label: parse_log(path) for label, path in files.items()}

# Create plot
fig, axs = plt.subplots(2, 1, figsize=(12, 8), sharex=True)

# Plot Latency
for label in data:
    seconds, _, lat = data[label]
    axs[0].plot(seconds, lat, label=f"{label} latency")

axs[0].set_ylabel("Latency (ms)")
axs[0].set_title("Latency Comparison (with Baseline)")
axs[0].legend()
axs[0].grid(True, linestyle="--", alpha=0.6)

# Plot Throughput
for label in data:
    seconds, ops, _ = data[label]
    axs[1].plot(seconds, ops, label=f"{label} throughput")

axs[1].set_xlabel("Time (s)")
axs[1].set_ylabel("Ops/sec")
axs[1].set_title("Throughput Comparison (with Baseline)")
axs[1].legend()
axs[1].grid(True, linestyle="--", alpha=0.6)

plt.tight_layout()
plt.savefig("latency_throughput_comparison_with_baseline.png")
plt.show()
