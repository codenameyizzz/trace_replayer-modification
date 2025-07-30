#!/bin/bash

METHOD=fsync
TARGET_FILE="/home/cc/fuse_mount/test.txt"
LOG_FILE="delay_sweep_results.csv"

# Clear previous log
echo "delay_us,real_time_sec" > "$LOG_FILE"

# List of delay values in microseconds
for DELAY in 100000 200000 300000 400000 500000
do
  echo "[INFO] Setting delay = $DELAY us"
  
  # Set fault via python_client.py
  python3 python_client.py set_fault $METHOD false 0 100000 ".*test.txt" false $DELAY false
  
  # Run workload and capture real execution time
  EXEC_TIME=$( { time -p python3 -c 'import os; f = open("'"$TARGET_FILE"'", "a"); f.write("sweep\n"); f.flush(); os.fsync(f.fileno())'; } 2>&1 | grep real | awk '{print $2}' )
  
  # Log result
  echo "$DELAY,$EXEC_TIME" >> "$LOG_FILE"
  
  sleep 1  # Optional: cooldown between runs
done