#!/bin/bash

# Usage:
# ./run_netdelay.sh "cassandra_b cassandra_c" "50ms" 90 delay50ms_at20 20

set -euo pipefail

RAW_CONTAINERS="$1"
DELAY_VALUE="$2"
DURATION="$3"
RESULT_DIR="$4"
INJECT_AT_SECOND="$5"

TARGET_CONTAINERS=""
for C in $RAW_CONTAINERS; do
  TARGET_CONTAINERS="$TARGET_CONTAINERS $C"
done

echo "[INFO] Target containers     : $TARGET_CONTAINERS"
echo "[INFO] Delay value           : $DELAY_VALUE"
echo "[INFO] Total duration        : $DURATION seconds"
echo "[INFO] Delay injected at     : ${INJECT_AT_SECOND}s"
echo "[INFO] Result directory      : $RESULT_DIR"

mkdir -p "results/$RESULT_DIR"

# Step 1: Start cassandra-stress workload
echo "[INFO] Starting cassandra-stress workload in background..."
docker exec cassandra_a bash -c "
  nohup /opt/cassandra/tools/bin/cassandra-stress write cl=ALL duration=${DURATION}s \
    -node cassandra_a,cassandra_b,cassandra_c \
    -mode native cql3 -rate threads=100 \
    -col n=FIXED\\(1\\) -schema replication\\(factor=3\\) \
    -log level=TRACE \
    > /tmp/stress-output.log 2>&1 &
"

# Step 2: Wait before injecting delay
echo "[INFO] Waiting ${INJECT_AT_SECOND}s before injecting delay..."
sleep "${INJECT_AT_SECOND}"

# Step 3: Inject delay
for CONTAINER in $TARGET_CONTAINERS; do
  echo "[INFO] Injecting delay to $CONTAINER..."
  docker exec "$CONTAINER" bash -c "
    tc qdisc del dev eth0 root || true
    tc qdisc add dev eth0 root netem delay $DELAY_VALUE
  "
done

# Step 4: Wait for workload to finish (full duration + buffer)
WAIT=$((DURATION + 5))
echo "[INFO] Waiting ${WAIT}s for workload to complete..."
sleep "$WAIT"

# Step 5: Copy log
echo "[INFO] Copying stress log..."
docker cp cassandra_a:/tmp/stress-output.log "results/$RESULT_DIR/stress-output.log"

# Step 6: Save metadata
echo "[INFO] Delay $DELAY_VALUE injected at ${INJECT_AT_SECOND}s to $TARGET_CONTAINERS" > "results/$RESULT_DIR/metadata.txt"
date > "results/$RESULT_DIR/timestamp.txt"

# Step 7: Cleanup delay
for CONTAINER in $TARGET_CONTAINERS; do
  echo "[INFO] Removing delay from $CONTAINER..."
  docker exec "$CONTAINER" tc qdisc del dev eth0 root || true
done

echo "[INFO] Experiment done. Results in results/$RESULT_DIR"
