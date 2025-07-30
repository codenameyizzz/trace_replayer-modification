import os
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd

# Directory containing the latency logs
log_dir = "."  # Adjust this path as needed
files = [f for f in os.listdir(log_dir) if f.startswith("latency_") and f.endswith(".log")]

# Extract delay label and latency values from each file
latency_records = []

for filename in files:
    label = filename.replace("latency_", "").replace(".log", "")
    with open(os.path.join(log_dir, filename), "r") as f:
        for line in f:
            parts = line.strip().split(",")
            if len(parts) == 2 and parts[1].isdigit():
                latency_records.append({"Delay": label, "Latency (ms)": int(parts[1])})

# Create DataFrame
df = pd.DataFrame(latency_records)

# Plot boxplot
plt.figure(figsize=(10, 6))
sns.boxplot(data=df, x="Delay", y="Latency (ms)", palette="Set2")
plt.title("Latency Distribution by Delay Injection (Slow Leader)")
plt.xlabel("Injected Delay")
plt.ylabel("Latency (ms)")
plt.grid(True, axis='y', linestyle='--', alpha=0.5)
plt.tight_layout()
plt.show()
