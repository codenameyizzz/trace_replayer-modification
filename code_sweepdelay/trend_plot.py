import matplotlib.pyplot as plt
import os

# Path ke folder log hasil eksperimen delay
base_path = "d:/Repo/code_sweepdelay"

# File mapping: filename → label delay
file_map = {
    "stress-output_100us.txt": "100µs",
    "stress-output_1ms.txt": "1ms",
    "stress-output_10ms.txt": "10ms",
    "stress-output_100ms.txt": "100ms",
    "stress-output_1s.txt": "1s"
}

# Inisialisasi dua grafik: Throughput dan Latency
fig, axs = plt.subplots(1, 2, figsize=(18, 6))

# Loop tiap file log
for filename, label in file_map.items():
    filepath = os.path.join(base_path, filename)
    if not os.path.exists(filepath):
        print(f"{filename} not found, skipping.")
        continue

    throughput_list = []
    latency_list = []
    time_list = []
    time = 0

    with open(filepath, "r") as f:
        for line in f:
            if line.startswith("total,"):
                parts = line.strip().split(",")
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

# === Format subplot Throughput ===
axs[0].set_title("Throughput Over Time", fontsize=14)
axs[0].set_xlabel("Time (s)", fontsize=12)
axs[0].set_ylabel("Throughput (ops/sec)", fontsize=12)
axs[0].legend(title="Injected Delay")
axs[0].grid(True)

# === Format subplot Latency ===
axs[1].set_title("Latency Over Time", fontsize=14)
axs[1].set_xlabel("Time (s)", fontsize=12)
axs[1].set_ylabel("Latency (ms)", fontsize=12)
axs[1].legend(title="Injected Delay")
axs[1].grid(True)

plt.tight_layout()

# Simpan output sebagai file gambar
output_path = os.path.join(base_path, "trend_plot_delay.png")
plt.savefig(output_path)
plt.show()
