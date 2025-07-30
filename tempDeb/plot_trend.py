import re
import matplotlib.pyplot as plt

# Input file
files = {
    "1ms": "stress-output_1ms.log",
    "100ms": "stress-output_100ms.log"
}

def parse_trend_data(filename):
    ops = []
    mean_lat = []
    with open(filename, 'r') as f:
        for line in f:
            # Format per baris: total,        551448,   51264,   51264,   51264,     1.0,     1.2, ...
            match = re.match(r"total,\s+\d+,\s+([\d.]+),\s+\d+,\s+\d+,\s+([\d.]+)", line)
            if match:
                ops.append(float(match.group(1)))
                mean_lat.append(float(match.group(2)))
    return ops, mean_lat

# Parsing data
trend_data = {}
for label, path in files.items():
    ops, lat = parse_trend_data(path)
    trend_data[label] = {
        "ops": ops,
        "lat": lat
    }

# Plotting
fig, ax1 = plt.subplots(figsize=(10, 5))

x_1ms = range(len(trend_data["1ms"]["ops"]))
x_100ms = range(len(trend_data["100ms"]["ops"]))

# Plot ops/s
ax1.plot(x_1ms, trend_data["1ms"]["ops"], label="1ms Ops/s", color="green", linestyle="--")
ax1.plot(x_100ms, trend_data["100ms"]["ops"], label="100ms Ops/s", color="darkgreen")
ax1.set_xlabel("Time (s)")
ax1.set_ylabel("Ops/sec", color="green")
ax1.tick_params(axis="y", labelcolor="green")

# Plot latency on secondary axis
ax2 = ax1.twinx()
ax2.plot(x_1ms, trend_data["1ms"]["lat"], label="1ms Mean Latency", color="blue", linestyle="--")
ax2.plot(x_100ms, trend_data["100ms"]["lat"], label="100ms Mean Latency", color="navy")
ax2.set_ylabel("Mean Latency (ms)", color="blue")
ax2.tick_params(axis="y", labelcolor="blue")

# Combine legends
lines_labels = [*ax1.get_legend_handles_labels(), *ax2.get_legend_handles_labels()]
lines, labels = zip(*lines_labels)
plt.legend(lines, labels, loc="upper right")

plt.title("Trend Plot: Ops/sec and Mean Latency over Time")
plt.grid(True, linestyle='--', alpha=0.5)
plt.tight_layout()
plt.savefig("latency_trend_plot.png")
plt.show()
