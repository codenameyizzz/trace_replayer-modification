import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# Load the CSV file again after reset
file_path = Path("delay_sweep_results1.csv")
df = pd.read_csv(file_path)

# Display basic structure and a preview
df.head()

# Plot the delay sweep results
plt.figure(figsize=(8, 5))
plt.plot(df['delay_us'] / 1000, df['real_time_sec'], marker='o')
plt.title('Filesystem Delay Sweep (fsync)')
plt.xlabel('Injected Delay (ms)')
plt.ylabel('Real Execution Time (s)')
plt.grid(True)
plt.tight_layout()
plt.show()  