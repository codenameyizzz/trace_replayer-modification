import re
import matplotlib.pyplot as plt
import numpy as np

# File log input
files = {
    "1ms": "stress-output_1ms.log",
    "100ms": "stress-output_100ms.log"
}

# Key yang ingin diambil
latency_metrics = {
    "Latency mean": [],
    "Latency 95th percentile": [],
    "Latency 99.9th percentile": [],
    "Latency max": []
}

# Proses ekstraksi
for label, file in files.items():
    with open(file, "r") as f:
        content = f.read()

    for metric in latency_metrics:
        match = re.search(rf"{re.escape(metric)}\s*:\s*([\d.]+) ms", content)
        if match:
            latency_metrics[metric].append(float(match.group(1)))
        else:
            latency_metrics[metric].append(0.0)  # fallback

# Data untuk plot
labels = list(files.keys())
x = np.arange(len(labels))  # 1ms, 100ms
width = 0.2

# Set warna dan label
metric_keys = list(latency_metrics.keys())
colors = ["orange", "red", "deeppink", "magenta"]

# Plot
fig, ax = plt.subplots(figsize=(10, 5))

for i, (metric, color) in enumerate(zip(metric_keys, colors)):
    ax.bar(x + i * width - width*1.5, latency_metrics[metric], width, label=f"{metric} (ms)", color=color)

ax.set_xlabel("Network Delay")
ax.set_ylabel("Latency (ms)")
ax.set_title("Latency Metrics under Network Delay")
ax.set_xticks(x)
ax.set_xticklabels(labels)
ax.legend(title="Latency Percentiles")
ax.grid(True, linestyle="--", alpha=0.5)

plt.tight_layout()
plt.savefig("latency_bar_comparison.png")
plt.show()
