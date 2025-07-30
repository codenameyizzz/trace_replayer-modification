import pandas as pd
import matplotlib.pyplot as plt
import glob
import os

# === Konfigurasi ===
log_files = sorted(glob.glob("latency_x*ms.log"))
colors = plt.cm.tab10.colors  # Palet warna

def detect_fault_start(series, threshold=0.8, warmup=20):
    """
    Deteksi kapan throughput drop pertama kali di bawah threshold * baseline.
    """
    baseline = series.iloc[:warmup].mean()
    drop_idx = series[series < baseline * threshold].first_valid_index()
    return drop_idx if drop_idx is not None else None

plt.figure(figsize=(12, 6))

# === Proses setiap file log ===
for i, filepath in enumerate(log_files):
    label = os.path.splitext(os.path.basename(filepath))[0].replace("latency_", "")
    timestamps = []

    # === Load file log ===
    with open(filepath, "r") as f:
        for line in f:
            if "," not in line:
                continue
            ts = line.strip().split(",")[0]
            if ts.isdigit():
                timestamps.append(int(ts) // 1000)

    if not timestamps:
        continue

    # === Hitung throughput per detik ===
    df = pd.Series(timestamps).value_counts().sort_index()
    full_range = pd.Series(0, index=range(df.index.min(), df.index.max() + 1))
    full_range.update(df)
    throughput = full_range.rolling(window=3, center=True).mean()

    # === Deteksi Fault Start dari data ===
    detected_start = detect_fault_start(throughput)
    if detected_start is None:
        detected_start = throughput.index.min()

    # === Plot throughput ===
    plt.plot(throughput.index - throughput.index.min(),
             throughput.values,
             label=label,
             color=colors[i % len(colors)],
             linewidth=1.5)

    # === Garis Fault Start untuk kurva ini ===
    plt.axvline(detected_start - throughput.index.min(),
                color=colors[i % len(colors)],
                linestyle="--",
                alpha=0.5)

# === Label dan Layout ===
plt.title("Slow Leader Mid Injection: Throughput vs Time", fontsize=14)
plt.xlabel("Time (seconds)")
plt.ylabel("Throughput (ops/sec)")
plt.legend(title="Delay Config")
plt.grid(True, linestyle="--", alpha=0.5)
plt.tight_layout()
plt.show()
