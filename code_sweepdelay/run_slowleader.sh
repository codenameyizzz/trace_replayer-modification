#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 5 ]; then
  echo "Usage: $0 <delay_value> <duration_seconds> <label> <fault_type> <inject_at>"
  echo "Example: $0 100ms 120 slowleader_mid2end delay 60"
  exit 1
fi

DELAY="$1"
DURATION="$2"
LABEL="$3"
MODE="$4"
INJECT_AT="$5"    # Waktu (detik) kapan fault mulai diaktifkan

LEADER="etcd0"
BENCH_NODE="etcd1"
ENDPOINTS="http://etcd0:2379,http://etcd1:2379,http://etcd2:2379"
OUTDIR="etcd_bench_results/$(date +%Y%m%d_%H%M%S)_${LABEL}"
mkdir -p "$OUTDIR"

echo "[INFO] Label       : $LABEL"
echo "[INFO] Delay Mode  : $MODE $DELAY"
echo "[INFO] Fault inject at second : $INJECT_AT"
echo "[INFO] Output dir  : $OUTDIR"

# Benchmark parameters
TOTAL=10000
PARALLELISM=10
LATLOG="$OUTDIR/latency.log"
: > "$LATLOG"

# === Jalankan benchmark di background ===
START_MS=$(date +%s%3N)
echo "[INFO] Starting benchmark PUTs ($TOTAL ops, $PARALLELISM parallel)..."

seq 1 "$TOTAL" | xargs -P"$PARALLELISM" -n1 -I{} sh -c '
  S=$(date +%s%3N)
  docker exec -e ETCDCTL_API=3 etcd1 etcdctl --endpoints="'"$ENDPOINTS"'" put key{} val{} >/dev/null 2>&1
  E=$(date +%s%3N)
  echo "$S,$((E-S))" >> "'"$LATLOG"'"
' &

BENCH_PID=$!

# === Tunggu hingga waktu injeksi ===
echo "[INFO] Waiting until $INJECT_AT seconds before injecting fault..."
sleep "$INJECT_AT"

# === Injeksi fault baru di mid-run ===
echo "[INFO] Injecting fault to LEADER ($LEADER) at $INJECT_AT seconds..."
docker run --rm --privileged --net container:"$LEADER" nicolaka/netshoot \
  sh -c "tc qdisc del dev eth0 root 2>/dev/null || true; tc qdisc add dev eth0 root netem $MODE $DELAY"

# === Tunggu sampai benchmark selesai ===
wait $BENCH_PID || true
END_MS=$(date +%s%3N)

# === Cleanup delay setelah benchmark selesai ===
echo "[INFO] Removing netem from $LEADER..."
docker run --rm --privileged --net container:"$LEADER" nicolaka/netshoot \
  sh -c "tc qdisc del dev eth0 root 2>/dev/null || true"

ELAPSED_MS=$((END_MS - START_MS))

# === Hitung throughput dan percentiles ===
SORTED_LAT=$(mktemp)
cut -d',' -f2 "$LATLOG" | grep -E '^[0-9]+$' | sort -n > "$SORTED_LAT"
CNT=$(wc -l < "$SORTED_LAT")
p50=$(awk -v c=$CNT 'NR==int(c*0.50+0.5)' "$SORTED_LAT")
p95=$(awk -v c=$CNT 'NR==int(c*0.95+0.5)' "$SORTED_LAT")
p99=$(awk -v c=$CNT 'NR==int(c*0.99+0.5)' "$SORTED_LAT")
pmax=$(tail -n1 "$SORTED_LAT")
rm -f "$SORTED_LAT"

THROUGHPUT=$((TOTAL * 1000 / ELAPSED_MS))

# === Summary ===
{
  echo "Latency median (p50)       : $p50 ms"
  echo "Latency 95th percentile    : $p95 ms"
  echo "Latency 99th percentile    : $p99 ms"
  echo "Latency max                : $pmax ms"
  echo "Total ops                  : $TOTAL"
  echo "Elapsed ms                 : $ELAPSED_MS"
  echo "Throughput                 : $THROUGHPUT ops/sec"
} | tee "$OUTDIR/summary.txt"

# === Metadata ===
cat <<EOF > "$OUTDIR/metadata.txt"
timestamp=$(date)
label=$LABEL
mode=$MODE
delay=$DELAY
duration=$DURATION
inject_at=$INJECT_AT
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

echo "[SUCCESS] Completed mid-to-end fault experiment. Results saved to: $OUTDIR"