import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("summary_netdelay.csv")
df = df.sort_values("delay_ms")

# Plot Throughput vs Delay
plt.figure()
plt.plot(df["delay_ms"], df["throughput_ops"], marker='o')
plt.title("Throughput vs Injected Delay")
plt.xlabel("Delay Injected (ms)")
plt.ylabel("Throughput (ops/sec)")
plt.grid(True)
plt.tight_layout()
plt.savefig("netdelay_throughput.png")

# Plot Latency vs Delay
plt.figure()
plt.plot(df["delay_ms"], df["latency_mean"], marker='o', label="Mean")
plt.plot(df["delay_ms"], df["latency_p95"], marker='o', label="P95")
plt.plot(df["delay_ms"], df["latency_max"], marker='o', label="Max")
plt.title("Latency vs Injected Delay")
plt.xlabel("Delay Injected (ms)")
plt.ylabel("Latency (ms)")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.savefig("netdelay_latency.png")
plt.show()
