#!/bin/bash

# Script ini menjalankan sweep delay untuk berbagai variasi delay
# Pastikan script run_netdelay.sh sudah bisa dijalankan

set -euo pipefail

TARGET_CONTAINERS="cassandra_b cassandra_c"
INJECT_AT_SECOND=20
DURATION=90
DELAYS=("1ms" "10ms" "20ms" "50ms" "75ms" "100ms")

LOGFILE="sweep_runlog.txt"
echo "[INFO] Starting sweep at $(date)" >> "$LOGFILE"

# Pastikan kontainer Cassandra aktif
if ! docker ps --format '{{.Names}}' | grep -q cassandra_a; then
  echo "[ERROR] Cassandra containers are not running. Please start them with: docker compose up -d"
  exit 1
fi

for DELAY in "${DELAYS[@]}"; do
  LABEL="delay${DELAY}_at${INJECT_AT_SECOND}"
  echo "======================================"
  echo "Running experiment: $LABEL"
  echo "======================================"
  echo "[INFO] $LABEL started at $(date)" >> "$LOGFILE"

  if [ -d "results/$LABEL" ]; then
    echo "[WARN] Result directory results/$LABEL already exists. Skipping..."
    continue
  fi

  ./run_netdelay.sh "$TARGET_CONTAINERS" "$DELAY" "$DURATION" "$LABEL" "$INJECT_AT_SECOND"

  echo "[INFO] $LABEL completed at $(date)" >> "$LOGFILE"
  echo ""
  echo "✅ Finished $LABEL. Sleeping 10s before next..."
  sleep 10
done

echo "✅ All delay experiments completed at $(date)" >> "$LOGFILE"
echo "✅ Sweep completed."
