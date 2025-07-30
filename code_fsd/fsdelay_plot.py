import pandas as pd
import matplotlib.pyplot as plt

# Load results
df = pd.read_csv("delay_sweep_results.csv")

# Plot
plt.figure(figsize=(8, 5))
plt.plot(df['delay_us'], df['real_time_us'], marker='o')
plt.xlabel("Injected Delay (µs)")
plt.ylabel("Observed Fsync Time (µs)")
plt.title("Filesystem Delay Fault Injection (fsync)")
plt.grid(True)
plt.tight_layout()
plt.savefig("delay_sweep_plot.png")
plt.show()
