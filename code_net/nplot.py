import re
import matplotlib.pyplot as plt

# Initialize lists for storing parsed data
time_list = []
throughput_list = []
mean_latency_list = []

# Parse the updated stress-output.txt
with open("stress-output.txt", "r") as file:
    for line in file:
        if line.startswith("total,"):
            parts = line.strip().split(",")
            if len(parts) >= 6:
                try:
                    throughput = float(parts[1].strip())
                    mean_latency = float(parts[5].strip())
                    timestamp = float(parts[12].strip())  # Extract time column for X-axis
                    time_list.append(timestamp)
                    throughput_list.append(throughput)
                    mean_latency_list.append(mean_latency)
                except ValueError:
                    continue

# Create subplots for throughput and mean latency
fig, axs = plt.subplots(1, 2, figsize=(14, 5))

# Throughput subplot
axs[0].plot(time_list, throughput_list, label="Throughput (ops/sec)", marker='o')
axs[0].set_xlabel("Time (s)")
axs[0].set_ylabel("Throughput")
axs[0].set_title("Throughput Over Time")
axs[0].grid(True)

# Mean latency subplot
axs[1].plot(time_list, mean_latency_list, label="Mean Latency (ms)", color='orange', marker='x')
axs[1].set_xlabel("Time (s)")
axs[1].set_ylabel("Mean Latency (ms)")
axs[1].set_title("Mean Latency Over Time")
axs[1].grid(True)

plt.tight_layout()
plt.savefig("stress_output_trend_plot.png")
plt.show()
