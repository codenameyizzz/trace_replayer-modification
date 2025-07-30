import os
import matplotlib.pyplot as plt

def load_latencies(filepath, cap=None):
    latencies = []
    with open(filepath, 'r') as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.strip().split(',')
            if len(parts) < 2:
                continue
            try:
                latency = float(parts[1])
                if cap is None or latency <= cap:
                    latencies.append(latency)
            except ValueError:
                continue
    return latencies

# Folder path
log_dir = 'D:/Repo/test_osfn'
log_files = sorted([f for f in os.listdir(log_dir) if f.endswith('.log')])

plt.figure(figsize=(10, 6))

for filename in log_files:
    path = os.path.join(log_dir, filename)
    latencies = load_latencies(path)
    if not latencies:
        continue
    latencies.sort()
    cdf = [i / len(latencies) for i in range(len(latencies))]

    # Ambil label dari nama file, contoh: DELAY1000
    label = filename.split('_')[-1].replace('.log', '')
    plt.plot(latencies, cdf, label=label)

plt.xlabel("Latency (µs)")
plt.ylabel("CDF")
plt.title("Filesystem Delay CDF per Configuration")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("cdf_fsdelay_plot.png")
plt.show()
