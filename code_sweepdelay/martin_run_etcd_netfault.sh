#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 4 ]; then
  echo "Usage: $0 MODE [FOLLOWER...] VALUE DURATION_s LABEL"
  exit 1
fi

# 1) parse args
MODE="$1"; shift
ARGS=("$@"); N=${#ARGS[@]}
VALUE="${ARGS[N-3]}"    # e.g. "40%" or "100ms"
DURATION="${ARGS[N-2]}" # e.g. "60s"
LABEL="${ARGS[N-1]}"    # e.g. baseline, loss40, delay100
FOLLOWERS=("${ARGS[@]:0:N-3}")

# filter out empties
REAL_FOLLOWERS=()
for f in "${FOLLOWERS[@]}"; do
  [[ -n "$f" ]] && REAL_FOLLOWERS+=("$f")
done

# 2) prepare out‑dir under ./martin
OUTBASE="./martin"
mkdir -p "$OUTBASE"
STAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR="$OUTBASE/${STAMP}_${LABEL}"
mkdir -p "$OUTDIR"

ENDPTS="http://etcd0:2379,http://etcd1:2379,http://etcd2:2379"

# 3) report run settings (into run.log)
{
  echo "[INFO] Label     : $LABEL"
  echo "[INFO] Mode      : $MODE"
  echo "[INFO] Followers : ${REAL_FOLLOWERS[*]:-none}"
  echo "[INFO] Value     : $VALUE"
  echo "[INFO] Duration  : $DURATION"
  echo "[INFO] Endpoints : $ENDPTS"
  echo "[INFO] Output    : $OUTDIR"
  echo
} | tee "$OUTDIR/run.log"

# 4) clear any existing qdisc on all nodes
for C in etcd0 etcd1 etcd2; do
  echo "[NETEM] Clearing qdisc on $C" | tee -a "$OUTDIR/run.log"
  docker run --rm --privileged --net container:"$C" nicolaka/netshoot:latest \
    sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"
done

# 5) inject NetEm on the specified followers
if (( ${#REAL_FOLLOWERS[@]} > 0 )); then
  for C in "${REAL_FOLLOWERS[@]}"; do
    echo "[NETEM] Injecting $MODE=$VALUE → $C" | tee -a "$OUTDIR/run.log"
    docker run --rm --privileged --net container:"$C" nicolaka/netshoot:latest \
      sh -c "tc qdisc add dev eth0 root netem $MODE $VALUE"
  done
  echo "[INFO] Settling for ${DURATION%?}s…" | tee -a "$OUTDIR/run.log"
  sleep "${DURATION%?}"
else
  echo "[INFO] No netem injection requested" | tee -a "$OUTDIR/run.log"
fi
echo | tee -a "$OUTDIR/run.log"

# 6) health‐check endpoints
echo "[INFO] Performing endpoint health checks…" | tee "$OUTDIR/health.log"
HEALTHY=()
while IFS= read -r line; do
  echo "  $line" | tee -a "$OUTDIR/health.log"
  if [[ "$line" =~ ^(http[^[:space:]]+)[[:space:]]+is\ healthy ]]; then
    HEALTHY+=("${BASH_REMATCH[1]}")
  fi
done < <(docker exec etcd0 etcdctl endpoint health --endpoints="$ENDPTS" 2>&1)

if [ ${#HEALTHY[@]} -eq 0 ]; then
  echo "[WARN] No healthy → falling back to leader only" | tee -a "$OUTDIR/health.log"
  HEALTHY=(http://etcd0:2379)
fi

# 7) build EP_LIST; for faults, prefix slow followers
if (( ${#REAL_FOLLOWERS[@]} == 0 )); then
  EP_LIST="http://etcd0:2379,http://etcd1:2379,http://etcd2:2379"
else
  PREFIX=(); OTHERS=()
  for f in "${REAL_FOLLOWERS[@]}"; do PREFIX+=("http://${f}:2379"); done
  for ep in "${HEALTHY[@]}"; do
    skip=false
    for f in "${REAL_FOLLOWERS[@]}"; do
      [[ "$ep" == *"$f:2379" ]] && { skip=true; break; }
    done
    $skip || OTHERS+=("$ep")
  done
  EP_LIST=$(IFS=,; echo "${PREFIX[*]},${OTHERS[*]}")
fi

echo
echo "[INFO] Using endpoints for load test: $EP_LIST" | tee -a "$OUTDIR/run.log"
echo | tee -a "$OUTDIR/run.log"

# 8) run 10 000 puts in parallel and log per‑op latency
TOTAL=10000
LATFILE="$OUTDIR/latencies_ms.log"
: > "$LATFILE"

echo "[INFO] Running $TOTAL puts (10 parallel) …" | tee -a "$OUTDIR/run.log"
START_MS=$(date +%s%3N)
export EP_LIST

seq 1 "$TOTAL" | xargs -P10 -n1 -I{} sh -c '
  S=$(date +%s%3N)
  # suppress errors so netem losses/timeouts don’t pollute results
  docker exec etcd0 sh -c "
    ETCDCTL_API=3 etcdctl --endpoints=\"$EP_LIST\" put key{} value{} >/dev/null 2>&1
  " >/dev/null 2>&1 || true
  E=$(date +%s%3N)
  echo $((E-S))
' >>"$LATFILE"'

END_MS=$(date +%s%3N)
ELAPSED=$((END_MS-START_MS))
RPS=$(( TOTAL*1000/ELAPSED ))

# 9) compute percentiles
NUMS=($(grep -E '^[0-9]+$' "$LATFILE" | sort -n))
CNT=${#NUMS[@]}
p50=${NUMS[$((CNT*50/100))]}
p95=${NUMS[$((CNT*95/100))]}
p99=${NUMS[$((CNT*99/100))]}
pmax=${NUMS[-1]}

# 10) Cassandra‑style stress log
cat >"$OUTDIR/etcd_stress.log" <<EOF
******************** Stress Settings ********************
Command:
  Type:        put
  Count:       $TOTAL
  Parallelism: 10
  Netem Mode:  $MODE
  Netem Value: $VALUE
  Followers:   ${REAL_FOLLOWERS[*]:-none}
Endpoints:
  $EP_LIST

type, total ops, op/s, median,  .95,  .99,  max, time_s
total, $TOTAL, $RPS, $p50, $p95, $p99, $pmax, $((ELAPSED/1000))
EOF

# 11) simple percentile summary
{
  printf "Latency median            : %8.3f ms\n" "$p50"
  printf "Latency 95th percentile   : %8.3f ms\n" "$p95"
  printf "Latency 99th percentile   : %8.3f ms\n" "$p99"
  printf "Latency max               : %8.3f ms\n" "$pmax"
  echo
  printf "Total puts                : %8d\n" "$TOTAL"
  printf "Throughput                : %8d ops/sec\n" "$RPS"
} | tee "$OUTDIR/benchmark.log"

# 12) metadata
cat >"$OUTDIR/metadata.txt" <<EOF
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

# 13) cleanup NetEm on followers
if (( ${#REAL_FOLLOWERS[@]} > 0 )); then
  for C in "${REAL_FOLLOWERS[@]}"; do
    echo "[NETEM] Removing qdisc on $C"
    docker run --rm --privileged --net container:"$C" nicolaka/netshoot:latest \
      sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"
  done
fi

echo "[SUCCESS] Completed. Results in $OUTDIR"
