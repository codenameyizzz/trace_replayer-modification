import re
import matplotlib.pyplot as plt

# Paths to the uploaded files
files = {
    "1ms": "stress-output_1ms.log",
    "100ms": "stress-output_100ms.log"
}

# Function to extract metrics per second
def parse_log(filepath):
    seconds = []
    ops = []
    mean_lat = []
    p95_lat = []
    p999_lat = []
    max_lat = []

    with open(filepath, "r") as f:
        second = 0
        for line in f:
            match = re.match(
                r"total,\s+\d+,\s+([\d.]+),\s+\d+,\s+\d+,\s+([\d.]+),\s+[\d.]+,\s+([\d.]+),\s+[\d.]+,\s+([\d.]+),\s+([\d.]+)",
                line
            )
            if match:
                ops.append(float(match.group(1)))
                mean_lat.append(float(match.group(2)))
                p95_lat.append(float(match.group(3)))
                p999_lat.append(float(match.group(4)))
                max_lat.append(float(match.group(5)))
                seconds.append(second)
                second += 1
    return seconds, ops, mean_lat, p95_lat, p999_lat, max_lat

# Parse both files
data = {label: parse_log(path) for label, path in files.items()}

# Plot
fig, axs = plt.subplots(2, 1, figsize=(14, 8), sharex=True)

# Define line styles
line_styles = {
    "Mean": 2,
    "P95": 3,
    "P99.9": 4,
    "Max": 5
}
colors = {
    "1ms": "blue",
    "100ms": "red"
}

# Latency plot
for metric, idx in line_styles.items():
    for label in files:
        seconds = data[label][0]
        lat = data[label][idx]
        axs[0].plot(seconds, lat, label=f"{label} {metric}", linestyle='-' if label == "1ms" else '--', color=colors[label])
axs[0].set_title("Latency Trends")
axs[0].set_ylabel("Latency (ms)")
axs[0].legend()
axs[0].grid(True, linestyle="--", alpha=0.6)

# Throughput plot
for label in files:
    seconds = data[label][0]
    ops = data[label][1]
    axs[1].plot(seconds, ops, label=f"{label} Throughput", linestyle='-' if label == "1ms" else '--', color=colors[label])
axs[1].set_title("Throughput Trends")
axs[1].set_xlabel("Time (s)")
axs[1].set_ylabel("Operations/sec")
axs[1].legend()
axs[1].grid(True, linestyle="--", alpha=0.6)

plt.tight_layout()
plt.show()
