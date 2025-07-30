import pandas as pd
import matplotlib.pyplot as plt

# Load and sort CSV
df = pd.read_csv("delay_sweep_results.csv")
df = df.sort_values("delay_us")

# Plot line chart with log Y scale
plt.figure(figsize=(8, 5))
plt.plot(df['delay_us'], df['real_time_us'], marker='o', label="Observed fsync time")
plt.axhline(y=df[df['delay_us'] == 0]['real_time_us'].values[0], color='red', linestyle='--', label='Baseline (no delay)')

plt.xlabel("Injected Delay (µs)")
plt.ylabel("Observed Fsync Time (µs, log scale)")
plt.yscale('log')
plt.title("Trend Plot: Injected Delay vs Observed fsync Time (Log Scale)")
plt.legend()
plt.grid(True, which='both', axis='y', linestyle='--')
plt.tight_layout()
plt.savefig("trend_plot_log.png")
plt.show()
