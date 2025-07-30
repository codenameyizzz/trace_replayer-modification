#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 4 ]; then
  echo "Usage: $0 MODE [FOLLOWER...] VALUE DURATION_s LABEL"
  exit 1
fi

# 1) Parse arguments
MODE="$1"; shift
ARGS=("$@"); N=${#ARGS[@]}
VALUE="${ARGS[N-3]}"     # e.g. "40%" or "50ms"
DURATION="${ARGS[N-2]}"  # e.g. "60s"
LABEL="${ARGS[N-1]}"     # e.g. loss40
FOLLOWERS=("${ARGS[@]:0:N-3}")

# filter out any empty entries
REAL_FOLLOWERS=()
for f in "${FOLLOWERS[@]}"; do
  [[ -n "$f" ]] && REAL_FOLLOWERS+=("$f")
done

# 2) Prepare directories
OUTBASE="./etcd_bench_results"
mkdir -p "$OUTBASE"
STAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR="$OUTBASE/${STAMP}_${LABEL}"
mkdir -p "$OUTDIR"

ENDPTS="http://etcd0:2379,http://etcd1:2379,http://etcd2:2379"

echo "[INFO] Label     : $LABEL"
echo "[INFO] Mode      : $MODE"
echo "[INFO] Followers : ${REAL_FOLLOWERS[*]:-none}"
echo "[INFO] Value     : $VALUE"
echo "[INFO] Duration  : $DURATION"
echo "[INFO] Endpoints : $ENDPTS"
echo "[INFO] Output    : $OUTDIR"
echo

# 3) NetEm injection
if (( ${#REAL_FOLLOWERS[@]} > 0 )); then
  for C in "${REAL_FOLLOWERS[@]}"; do
    echo "[NETEM] Clearing any existing qdisc on $C"
    docker run --rm --privileged --net container:"$C" nicolaka/netshoot:latest \
      sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"

    echo "[NETEM] Injecting $MODE=$VALUE → $C"
    docker run --rm --privileged --net container:"$C" nicolaka/netshoot:latest \
      sh -c "tc qdisc add dev eth0 root netem $MODE $VALUE"
  done
  echo "[INFO] Settling for 5s…"
  sleep 5
else
  echo "[INFO] No netem injection requested"
fi
echo

# 4) Per-endpoint health check (never fatal)
echo "[INFO] Performing endpoint health checks…" | tee "$OUTDIR/health.log"
HEALTHY_ENDPOINTS=()
while IFS= read -r line; do
  echo "  $line" | tee -a "$OUTDIR/health.log"
  if [[ "$line" =~ ^(http[^[:space:]]+)[:space]+is\ healthy ]]; then
    HEALTHY_ENDPOINTS+=("${BASH_REMATCH[1]}")
  fi
done < <(docker exec etcd0 etcdctl endpoint health --endpoints="$ENDPTS" 2>&1)

# If none healthy, fall back to the leader only
if [ ${#HEALTHY_ENDPOINTS[@]} -eq 0 ]; then
  echo "[WARN] No healthy followers detected — falling back to leader only" | tee -a "$OUTDIR/health.log"
  HEALTHY_ENDPOINTS=(http://etcd0:2379)
fi

# Reconstruct endpoint list for the load test
EP_LIST=$(IFS=,; echo "${HEALTHY_ENDPOINTS[*]}")

echo
echo "[INFO] Using endpoints for load test: $EP_LIST"
echo

# 5) Run 10 000 puts and record per‑operation latency
TOTAL=10000
LATFILE="$OUTDIR/latencies_ms.log"
: > "$LATFILE"
echo "[INFO] Running $TOTAL puts (10 parallel) against $EP_LIST…"
START_ALL=$(date +%s%3N)

seq 1 $TOTAL | xargs -P10 -n1 -I{} sh -c '
  S=$(date +%s%3N)
  # suppress any errors; only record elapsed ms
  docker exec etcd0 sh -c \
    "ETCDCTL_API=3 etcdctl --endpoints=\"'"$EP_LIST"'\" --command-timeout=300s put key{} value{} >/dev/null 2>&1" \
    >/dev/null 2>&1 || true
  E=$(date +%s%3N)
  echo $((E-S))
' >>"$LATFILE"

END_ALL=$(date +%s%3N)
ELAPSED=$((END_ALL-START_ALL))
RPS=$(( TOTAL*1000/ELAPSED ))

# 6) Compute percentiles
SORTED=$(sort -n "$LATFILE")
CNT=$(wc -l <"$LATFILE")
p50=$(awk -v c=$CNT 'NR==int(c*0.50+0.5){print}' <<<"$SORTED")
p95=$(awk -v c=$CNT 'NR==int(c*0.95+0.5){print}' <<<"$SORTED")
p99=$(awk -v c=$CNT 'NR==int(c*0.99+0.5){print}' <<<"$SORTED")
pmax=$(tail -n1 <<<"$SORTED")

# 7) Output stress‑style summary
{
  printf "Latency median            : %8.3f ms\n" "$p50"
  printf "Latency 95th percentile   : %8.3f ms\n" "$p95"
  printf "Latency 99th percentile   : %8.3f ms\n" "$p99"
  printf "Latency max               : %8.3f ms\n" "$pmax"
  echo
  printf "Total puts                : %8d\n" "$TOTAL"
  printf "Throughput                : %8d ops/sec\n" "$RPS"
} | tee "$OUTDIR/benchmark.log"

# 8) Metadata
cat > "$OUTDIR/metadata.txt" <<EOF
mode=$MODE
followers=${REAL_FOLLOWERS[*]:-none}
value=$VALUE
duration=$DURATION
endpoints=$EP_LIST
total_puts=$TOTAL
elapsed_ms=$ELAPSED
throughput_ops_per_s=$RPS
timestamp=$(date)
EOF
echo "[INFO] Metadata → $OUTDIR/metadata.txt"
echo

# 9) Cleanup netem
if (( ${#REAL_FOLLOWERS[@]} > 0 )); then
  for C in "${REAL_FOLLOWERS[@]}"; do
    echo "[NETEM] Removing qdisc on $C"
    docker run --rm --privileged --net container:"$C" nicolaka/netshoot:latest \
      sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"
  done
fi

echo "[SUCCESS] Completed. Results in $OUTDIR"
