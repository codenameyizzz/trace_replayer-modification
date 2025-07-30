set -euo pipefail

# Usage:
#   ./run_fault_experiment.sh <fault_type> "<nodes>" "<value>" <duration_s> <label>
#
# Examples in the table below.

FAULT_TYPE=${1:?fault_type (none|flaky|slow|partition)}
TARGET_NODES=${2}          # e.g. "a b" or "c"
FAULT_VALUE=${3}           # e.g. "10%" or "100ms" (empty for none/partition)
DURATION=${4:-30}          # seconds
LABEL=${5:-${FAULT_TYPE}_${FAULT_VALUE}}

OUTDIR="results/$(date +%Y%m%d_%H%M%S)_${LABEL}"
mkdir -p "$OUTDIR"

echo "=== Scenario: $LABEL ==="
echo " Fault   : $FAULT_TYPE $TARGET_NODES $FAULT_VALUE"
echo " Duration: ${DURATION}s"
echo " Output  : $OUTDIR"
echo

# 1) Tear down anything left over
docker compose down --remove-orphans >/dev/null 2>&1 || true
blockade destroy      >/dev/null 2>&1 || true
docker network rm blockade 2>/dev/null || true

# 2) Start fresh
docker compose up -d
sleep 10   # give Cassandra its JVM startup time
blockade up
blockade status
echo

# 3) Inject the fault
if [[ "$FAULT_TYPE" != "none" ]]; then
  if [[ "$FAULT_TYPE" == "partition" ]]; then
    blockade partition $TARGET_NODES
  else
    blockade $FAULT_TYPE $TARGET_NODES $FAULT_VALUE
  fi
  echo ">> Applied blockade: $FAULT_TYPE $TARGET_NODES $FAULT_VALUE"
  sleep 5
else
  echo ">> Baseline: no fault"
fi
echo

# 4) Start log capture
docker compose logs -f a b c >"$OUTDIR/docker-logs.txt" 2>&1 &
LOG_PID=$!

# 5) Run cassandra-stress in the *current* node a container
echo ">> Running cassandra-stress for ${DURATION}s…"
docker compose exec a bash -lc \
  "/opt/cassandra/tools/bin/cassandra-stress write \
     duration=\"${DURATION}s\" \
     -node 127.0.0.1:9042 \
     -schema 'replication(factor=3)' \
     -mode native cql3 \
     -col 'n=FIXED(1)' \
     -rate threads=50" \
  | tee "$OUTDIR/stress-output.txt"

# 6) Tear down logging
kill $LOG_PID || true
wait $LOG_PID 2>/dev/null || true

# 7) Record final Blockade state
blockade status >"$OUTDIR/blockade-status.txt" 2>&1 || true

# 8) Cleanup
blockade destroy >/dev/null 2>&1 || true
docker compose down

echo
echo "✅ Scenario '$LABEL' done. Results in $OUTDIR"
