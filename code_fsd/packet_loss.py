import re
import matplotlib.pyplot as plt

# === Extract metrics from stress-output.txt ===
time_list = []
throughput_list = []
mean_latency_list = []

with open("stress-output.txt", "r") as f:
    time_sec = 0
    for line in f:
        if line.startswith("total,"):
            parts = line.strip().split(",")
            if len(parts) >= 6:
                try:
                    throughput = float(parts[1].strip())
                    mean_latency = float(parts[5].strip())
                    time_sec += 1
                    time_list.append(time_sec)
                    throughput_list.append(throughput)
                    mean_latency_list.append(mean_latency)
                except ValueError:
                    continue

# === Subplots: Throughput & Latency ===
fig, axs = plt.subplots(1, 2, figsize=(14, 5))

# Left: Throughput
axs[0].plot(time_list, throughput_list, label="Throughput (ops/sec)", marker='o')
axs[0].set_xlabel("Time (s)")
axs[0].set_ylabel("Throughput")
axs[0].set_title("Throughput over Time")
axs[0].grid(True)

# Right: Mean Latency
axs[1].plot(time_list, mean_latency_list, label="Mean Latency (ms)", color='orange', marker='x')
axs[1].set_xlabel("Time (s)")
axs[1].set_ylabel("Latency (ms)")
axs[1].set_title("Mean Latency over Time")
axs[1].grid(True)

plt.tight_layout()
plt.savefig("stress_plot_subplots.png")
plt.show()
