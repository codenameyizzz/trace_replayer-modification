import re
import matplotlib.pyplot as plt

# File log yang ingin dibandingkan
files = {
    "1ms delay": "stress-output_1ms.log",
    "100ms delay": "stress-output_100ms.log"
}

latency_stats = {
    "type": [],
    "mean": [],
    "median": [],
    "p95": [],
    "p99": [],
    "max": []
}

# Regex untuk mengambil baris latency
latency_keys = {
    "Latency mean": "mean",
    "Latency median": "median",
    "Latency 95th percentile": "p95",
    "Latency 99th percentile": "p99",
    "Latency max": "max"
}

for label, file in files.items():
    with open(file, "r") as f:
        content = f.read()

    latency = {}

    for line in content.splitlines():
        for key, short in latency_keys.items():
            if key in line:
                match = re.search(r"([\d.]+) ms", line)
                if match:
                    latency[short] = float(match.group(1))

    # Simpan ke dict utama
    latency_stats["type"].append(label)
    for short in latency_keys.values():
        latency_stats.setdefault(short, []).append(latency.get(short, 0.0))

# Plot hasil
x_labels = latency_stats["type"]
x = range(len(x_labels))

plt.figure(figsize=(10, 6))
plt.plot(x, latency_stats["mean"], marker='o', label="Mean")
plt.plot(x, latency_stats["p95"], marker='o', label="P95")
plt.plot(x, latency_stats["p99"], marker='o', label="P99")
plt.plot(x, latency_stats["max"], marker='o', label="Max")

plt.xticks(x, x_labels)
plt.xlabel("Network Delay")
plt.ylabel("Latency (ms)")
plt.title("Latency vs Network Delay (Cassandra-Stress)")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("latency_comparison.png")
plt.show()
