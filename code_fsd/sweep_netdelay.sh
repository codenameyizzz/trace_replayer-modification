#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# sweep_delay.sh
#
# Runs 1-way network‐delay experiments for Cassandra per the paper:
#  100µs, 1ms, 10ms, 100ms, 1s
#
# Assumes you have:
#   • run_fault_experiment.sh in the same directory (executable)
#   • blockade & docker-compose working
# ------------------------------------------------------------------

# Array of delay values (paper: 100µs, 1ms, 10ms, 100ms, 1s)
DELAYS=("100us" "1ms" "10ms" "100ms" "1s")

# Which link to delay
TARGET="b c"

# How long to run each stress test (seconds)
DURATION=300

for DELAY in "${DELAYS[@]}"; do
  LABEL="delay${DELAY}"
  echo
  echo "=== Running scenario: $LABEL ($DELAY one-way on nodes $TARGET) ==="
  ./run_netdelay.sh delay "$TARGET" "$DELAY" "$DURATION" "$LABEL"
done

echo
echo "All delay scenarios complete."