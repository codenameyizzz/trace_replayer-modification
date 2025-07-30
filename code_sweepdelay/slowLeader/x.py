import pandas as pd
import matplotlib.pyplot as plt

# === Konfigurasi ===
latency_file = "latency_20ms.log"  # Ganti dengan path log mid-fault
fault_start = 40     # detik (mulai injeksi fault)
fault_end = 80       # detik (fault selesai)

# === Load Data ===
timestamps = []
with open(latency_file, "r") as f:
    for line in f:
        if "," not in line:
            continue
        ts = line.strip().split(",")[0]
        if ts.isdigit():
            timestamps.append(int(ts) // 1000)

# === Hitung throughput per detik ===
df = pd.Series(timestamps).value_counts().sort_index()

# Isi missing second dengan 0 dan smooth dengan rolling
full_range = pd.Series(0, index=range(df.index.min(), df.index.max() + 1))
full_range.update(df)
throughput = full_range.rolling(window=3, center=True).mean()

# === Plot ===
plt.figure(figsize=(10, 5))
plt.plot(throughput.index - throughput.index.min(), throughput.values, label="Throughput", color="steelblue")

# Anotasi fault injection
plt.axvline(fault_start, color="orange", linestyle="--", label="Fault Start")
plt.axvline(fault_end, color="red", linestyle="--", label="Fault End")

plt.title("Slow Leader Mid-Fault: Throughput vs Time", fontsize=14)
plt.xlabel("Time (seconds)")
plt.ylabel("Throughput (ops/sec)")
plt.legend()
plt.grid(True, linestyle="--", alpha=0.5)
plt.tight_layout()
plt.show()
