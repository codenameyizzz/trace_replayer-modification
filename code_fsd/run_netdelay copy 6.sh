#!/bin/bash

# Usage:
# ./run_netdelay.sh "cassandra_b cassandra_c" "50ms" 90 delay50ms_now

set -euo pipefail

RAW_CONTAINERS="$1"
DELAY_VALUE="$2"
DURATION="$3"
RESULT_DIR="$4"

TARGET_CONTAINERS=""
for C in $RAW_CONTAINERS; do
  TARGET_CONTAINERS="$TARGET_CONTAINERS $C"
done

echo "[INFO] Target containers     : $TARGET_CONTAINERS"
echo "[INFO] Delay value           : $DELAY_VALUE"
echo "[INFO] Total duration        : $DURATION seconds"
echo "[INFO] Result directory      : $RESULT_DIR"

mkdir -p "results/$RESULT_DIR"

# Step 1: Inject delay BEFORE workload starts
for CONTAINER in $TARGET_CONTAINERS; do
  echo "[INFO] Injecting delay to $CONTAINER..."
  docker exec "$CONTAINER" bash -c "
    tc qdisc del dev eth0 root || true
    tc qdisc add dev eth0 root netem delay $DELAY_VALUE
  "
done

# Optional: Allow delay to settle
echo "[INFO] Waiting 3s to settle delay..."
sleep 3

# Step 2: Start cassandra-stress workload
echo "[INFO] Starting cassandra-stress workload..."
docker exec cassandra_a bash -c "
  nohup /opt/cassandra/tools/bin/cassandra-stress write cl=ONE duration=${DURATION}s \
    -node cassandra_a,cassandra_b,cassandra_c \
    -mode native cql3 -rate threads=50 \
    -col n=FIXED\\(1\\) -schema replication\\(factor=3\\) \
    -log level=verbose \
    > /tmp/stress-output.log 2>&1 &
"

# Step 3: Wait for workload to complete
WAIT=$((DURATION + 5))
echo "[INFO] Waiting ${WAIT}s for workload to complete..."
sleep "$WAIT"

# Step 4: Copy stress log
echo "[INFO] Copying stress log..."
docker cp cassandra_a:/tmp/stress-output.log "results/$RESULT_DIR/stress-output.log"

# Step 5: Copy Cassandra system log (for timeout/retry evidence)
echo "[INFO] Copying Cassandra system.log for timeout analysis..."
docker exec cassandra_a cat /var/log/cassandra/system.log > "results/$RESULT_DIR/system-cassandra_a.log"
docker exec cassandra_b cat /var/log/cassandra/system.log > "results/$RESULT_DIR/system-cassandra_b.log"
docker exec cassandra_c cat /var/log/cassandra/system.log > "results/$RESULT_DIR/system-cassandra_c.log"

# Step 6: Save metadata
echo "[INFO] Delay $DELAY_VALUE injected BEFORE workload to $TARGET_CONTAINERS" > "results/$RESULT_DIR/metadata.txt"
date > "results/$RESULT_DIR/timestamp.txt"

# Step 7: Cleanup delay
for CONTAINER in $TARGET_CONTAINERS; do
  echo "[INFO] Removing delay from $CONTAINER..."
  docker exec "$CONTAINER" tc qdisc del dev eth0 root || true
done

echo "[SUCCESS] Experiment done. Results in results/$RESULT_DIR"