#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 5 ]; then
  echo "Usage: $0 <delay_value> <total_duration_s> <label> <fault_type> <fault_duration_s>"
  echo "Example: $0 50ms 120 slowleader_mid delay 40"
  exit 1
fi

DELAY="$1"            # e.g., 50ms
TOTAL_DURATION="$2"   # e.g., 120
LABEL="$3"            # e.g., slowleader_mid
MODE="$4"             # e.g., delay or loss
FAULT_DURATION="$5"   # e.g., 40 (durasi fault)

LEADER="etcd0"
BENCH_NODE="etcd1"
ENDPOINTS="http://etcd0:2379,http://etcd1:2379,http://etcd2:2379"

OUTDIR="etcd_bench_results/$(date +%Y%m%d_%H%M%S)_${LABEL}"
mkdir -p "$OUTDIR"

echo "[INFO] Label         : $LABEL"
echo "[INFO] Delay Value   : $DELAY (will inject in the middle)"
echo "[INFO] Total Duration: $TOTAL_DURATION s"
echo "[INFO] Fault Duration: $FAULT_DURATION s"
echo "[INFO] Output dir    : $OUTDIR"

# --- Variables for benchmark ---
TOTAL=10000
PARALLELISM=10
LATLOG="$OUTDIR/latency.log"
: > "$LATLOG"

# --- Schedule Fault Injection ---
NORMAL_PHASE=$(( (TOTAL_DURATION - FAULT_DURATION) / 2 ))

(
  echo "[INFO] [Scheduler] Waiting $NORMAL_PHASE s before injecting fault..."
  sleep "$NORMAL_PHASE"

  echo "[INFO] [Scheduler] Injecting fault: $MODE = $DELAY to leader ($LEADER)"
  docker run --rm --privileged --net container:"$LEADER" nicolaka/netshoot \
    sh -c "tc qdisc del dev eth0 root 2>/dev/null || true; tc qdisc add dev eth0 root netem $MODE $DELAY"

  sleep "$FAULT_DURATION"

  echo "[INFO] [Scheduler] Removing fault from leader ($LEADER)..."
  docker run --rm --privileged --net container:"$LEADER" nicolaka/netshoot \
    sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"

  echo "[INFO] [Scheduler] Fault cleared. Experiment continues normally."
) &   # Scheduler runs in background

# --- Benchmark Execution ---
echo "[INFO] Starting benchmark PUTs ($TOTAL ops, $PARALLELISM parallel)..."
START_MS=$(date +%s%3N)

seq 1 "$TOTAL" | xargs -P"$PARALLELISM" -n1 -I{} sh -c '
  S=$(date +%s%3N)
  docker exec -e ETCDCTL_API=3 etcd1 etcdctl --endpoints="'"$ENDPOINTS"'" put key{} val{} >/dev/null 2>&1
  E=$(date +%s%3N)
  echo "$S,$((E - S))" >> "'"$LATLOG"'"
'

END_MS=$(date +%s%3N)
ELAPSED_MS=$((END_MS - START_MS))
THROUGHPUT=$((TOTAL * 1000 / ELAPSED_MS))

# --- Wait remaining time if benchmark ends earlier ---
REMAINING=$((TOTAL_DURATION - ELAPSED_MS / 1000))
if [ "$REMAINING" -gt 0 ]; then
  echo "[INFO] Benchmark finished early. Waiting $REMAINING more seconds..."
  sleep "$REMAINING"
fi

# --- Compute Percentiles ---
SORTED_LAT=$(mktemp)
cut -d',' -f2 "$LATLOG" | grep -E '^[0-9]+$' | sort -n > "$SORTED_LAT"
CNT=$(wc -l < "$SORTED_LAT")
p50=$(awk -v c=$CNT 'NR==int(c*0.50+0.5)' "$SORTED_LAT")
p95=$(awk -v c=$CNT 'NR==int(c*0.95+0.5)' "$SORTED_LAT")
p99=$(awk -v c=$CNT 'NR==int(c*0.99+0.5)' "$SORTED_LAT")
pmax=$(tail -n1 "$SORTED_LAT")
rm -f "$SORTED_LAT"

# --- Save Summary ---
{
  echo "Latency median (p50)       : $p50 ms"
  echo "Latency 95th percentile    : $p95 ms"
  echo "Latency 99th percentile    : $p99 ms"
  echo "Latency max                : $pmax ms"
  echo "Total ops                  : $TOTAL"
  echo "Elapsed ms                 : $ELAPSED_MS"
  echo "Throughput                 : $THROUGHPUT ops/sec"
} | tee "$OUTDIR/summary.txt"

# --- Metadata ---
cat <<EOF > "$OUTDIR/metadata.txt"
timestamp=$(date)
label=$LABEL
mode=$MODE
delay=$DELAY
total_duration=$TOTAL_DURATION
fault_duration=$FAULT_DURATION
leader=$LEADER
benchmark_node=$BENCH_NODE
endpoints=$ENDPOINTS
total_ops=$TOTAL
parallelism=$PARALLELISM
elapsed_ms=$ELAPSED_MS
throughput_ops_per_sec=$THROUGHPUT
p50=$p50
p95=$p95
p99=$p99
pmax=$pmax
EOF

echo "[SUCCESS] Completed experiment with mid-fault injection. Results in $OUTDIR"