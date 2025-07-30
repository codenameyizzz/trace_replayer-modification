import matplotlib.pyplot as plt
import os

# Updated base path for uploaded files
base_path = "d:/Repo/code_sweepdelay/"

# File mapping: filename → delay label
file_map = {
    "stress-output10.txt": "100µs",
    "stress-output20.txt": "1ms",
    "stress-output30.txt": "10ms",
    "stress-output40.txt": "100ms",
    "stress-output50.txt": "1s"
}

# Create larger figure for better readability
fig, axs = plt.subplots(1, 2, figsize=(18, 6))

# Plot each file's data
for filename, label in file_map.items():
    filepath = os.path.join(base_path, filename)

    if not os.path.exists(filepath):
        print(f"File {filename} not found, skipping.")
        continue

    throughput_list = []
    latency_list = []
    time_list = []

    with open(filepath, "r") as file:
        time = 0
        for line in file:
            if line.startswith("total,"):
                parts = line.strip().split(",")
                if len(parts) >= 6:
                    try:
                        throughput = float(parts[1].strip())
                        latency = float(parts[5].strip())
                        throughput_list.append(throughput)
                        latency_list.append(latency)
                        time_list.append(time)
                        time += 1
                    except ValueError:
                        continue

    axs[0].plot(time_list, throughput_list, label=label)
    axs[1].plot(time_list, latency_list, label=label)

# Format the throughput subplot
axs[0].set_title("Throughput Over Time", fontsize=14)
axs[0].set_xlabel("Time (s)", fontsize=12)
axs[0].set_ylabel("Throughput (ops/sec)", fontsize=12)
axs[0].legend(title="Delay Level")
axs[0].grid(True)

# Format the latency subplot
axs[1].set_title("Mean Latency Over Time", fontsize=14)
axs[1].set_xlabel("Time (s)", fontsize=12)
axs[1].set_ylabel("Latency (ms)", fontsize=12)
axs[1].legend(title="Delay Level")
axs[1].grid(True)

plt.tight_layout()
output_path = os.path.join(base_path, "stress_multi_run_comparison_scaled.png")
plt.savefig(output_path)
plt.show()

output_path