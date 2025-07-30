set -euo pipefail

# Usage:
#   ./run_fault_experiment.sh <fault_type> "<nodes>" "<value>" <duration_s> <label>
#
# Examples in the table below.

FAULT_TYPE=${1:?fault_type (none|flaky|slow|partition)}
TARGET_NODES=${2} # e.g. "a b" or "c"
FAULT_VALUE=${3}  # e.g. "10%" or "100ms" (empty for none/partition)
DURATION=${4:-30} # seconds
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
blockade destroy >/dev/null 2>&1 || true
docker network rm blockade 2>/dev/null || true

# 2) Start fresh
docker compose up -d
sleep 10 # give Cassandra its JVM startup time
blockade up
blockade status
echo

# Warm-up phase

echo ">> Warm-up phase..."
docker compose exec a bash -lc \
  "/opt/cassandra/tools/bin/cassandra-stress write \
     duration=\"30s\" \
     -node cassandra_a:9042,cassandra_b:9042,cassandra_c:9042 \
     -schema 'replication(factor=3)' \
     -mode native cql3 \
     -col 'n=FIXED(1)' \
     -rate threads=100 \
     -cl QUORUM" \
  > /dev/null

# 3) Inject the fault
if [[ "$FAULT_TYPE" != "none" ]]; then
  if [[ "$FAULT_TYPE" == "partition" ]]; then
    blockade partition $TARGET_NODES
  elif [[ "$FAULT_TYPE" == "flaky" ]]; then
    blockade flaky $TARGET_NODES --percent "$FAULT_VALUE"
  elif [[ "$FAULT_TYPE" == "delay" ]]; then
    for NODE in $TARGET_NODES; do
      echo ">> Applying delay to $NODE: $FAULT_VALUE"
      docker exec $NODE tc qdisc replace dev eth0 root netem delay $FAULT_VALUE || true
      docker exec $NODE tc qdisc show dev eth0 >>"$OUTDIR/tc-${NODE}.txt" || true
    done
  else
    echo "Unknown fault type: $FAULT_TYPE"
    exit 1
  fi
  echo ">> Applied blockade: $FAULT_TYPE $TARGET_NODES $FAULT_VALUE"
  sleep 5
else
  echo ">> Baseline: no fault"
fi

# 4) Start log capture
docker compose logs -f a b c >"$OUTDIR/docker-logs.txt" 2>&1 &
LOG_PID=$!

# 5) Run cassandra-stress in the *current* node a container
echo ">> Running cassandra-stress for ${DURATION}s…"
docker compose exec a bash -lc \
  "/opt/cassandra/tools/bin/cassandra-stress write \
     duration=\"${DURATION}s\" \
     -node cassandra_a:9042,cassandra_b:9042,cassandra_c:9042 \
     -schema 'replication(factor=3)' \
     -mode native cql3 \
     -col 'n=FIXED(1)' \
     -rate threads=100 \
     -cl QUORUM" |
  tee "$OUTDIR/stress-output.txt"

# 5b) Calculate degradation if previous baseline exists
NORMAL_TP=$(grep "op rate" "$OUTDIR/stress-output.txt" | head -n1 | awk '{print $3}')
FAULT_TP=$(grep "op rate" "$OUTDIR/stress-output.txt" | tail -n1 | awk '{print $3}')
DEGRADATION=$(echo "scale=2; ( $NORMAL_TP - $FAULT_TP ) / $NORMAL_TP * 100" | bc)
echo "Throughput degradation: $DEGRADATION%" >> "$OUTDIR/summary.txt"

# 6) Tear down logging
kill $LOG_PID || true
wait $LOG_PID 2>/dev/null || true

# 7) Record final Blockade state
blockade status >"$OUTDIR/blockade-status.txt" 2>&1 || true

# 8) Cleanup
blockade destroy >/dev/null 2>&1 || true
docker compose down

echo
echo " Scenario '$LABEL' done. Results in $OUTDIR"
