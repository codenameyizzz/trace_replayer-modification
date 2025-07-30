#!/bin/bash

FUSE_FILE="/home/cc/fuse_mount/test.txt"
RESULT_LOG="delay_sweep_results.csv"
DELAY_LIST=(100 1000 10000 100000 1000000)  # in microseconds: 0.1ms to 1s

echo "delay_us,real_time_us" > $RESULT_LOG

for delay in "${DELAY_LIST[@]}"
do
    echo "[INFO] Setting delay = ${delay} us"
    python3 python_client.py set_fault fsync false 0 100000 ".*test.txt" false $delay false

    sync
    sleep 1  # Allow settings to take effect

    # Time the fsync workload
    TIME_US=$(python3 -c "
import time, os
f = open('$FUSE_FILE', 'a')
f.write('delay_test\n')
f.flush()
start = time.time()
os.fsync(f.fileno())
end = time.time()
print(int((end - start) * 1_000_000))  # convert to microseconds
")

    echo "$delay,$TIME_US" >> $RESULT_LOG
    echo "[RESULT] delay=$delay → actual=$TIME_US us"
done
