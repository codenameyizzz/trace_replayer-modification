import pandas as pd
import matplotlib.pyplot as plt

# Load results
df = pd.read_csv("delay_sweep_results.csv")

# Plot as histogram
plt.figure(figsize=(10, 6))
plt.bar(df['delay_us'].astype(str), df['real_time_us'], color='skyblue')

# Log scale for better visibility
plt.yscale('log')

# Labeling
plt.xlabel("Injected Delay (µs)")
plt.ylabel("Observed Fsync Time (µs) [log scale]")
plt.title("Filesystem Delay Fault Injection (fsync)")
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.tight_layout()

# Save and show
plt.savefig("delay_sweep_histogram_log.png")
plt.show()
