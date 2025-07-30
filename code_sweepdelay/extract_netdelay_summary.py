import re
import csv
import glob

# Ubah sesuai prefix file kamu
log_files = sorted(glob.glob("stress-output*.txt"), key=lambda f: int(re.search(r'(\d+)', f).group(1)))

with open("summary_netdelay.csv", "w", newline="") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["filename", "delay_ms", "throughput_ops", "latency_mean", "latency_p95", "latency_max"])

    for file in log_files:
        with open(file, 'r') as f:
            content = f.read()

            # Ekstrak delay dari nama file
            delay_match = re.search(r'stress-output(\d+)', file)
            delay_val = int(delay_match.group(1)) if delay_match else None

            # Regex to extract throughput & latency
            ops_match = re.search(r"Op rate\s+:\s+([\d,]+)", content)
            mean_match = re.search(r"Latency mean\s+:\s+([0-9.]+)", content)
            p95_match = re.search(r"Latency 95th percentile\s+:\s+([0-9.]+)", content)
            max_match = re.search(r"Latency max\s+:\s+([0-9.]+)", content)

            if all([ops_match, mean_match, p95_match, max_match]):
                ops = int(ops_match.group(1).replace(",", ""))
                mean = float(mean_match.group(1))
                p95 = float(p95_match.group(1))
                maxv = float(max_match.group(1))
                writer.writerow([file, delay_val, ops, mean, p95, maxv])
