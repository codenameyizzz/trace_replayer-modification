#!/usr/bin/env bash
set -euo pipefail

MODE="$1"               # 'loss' or 'delay'
RAW_CONTAINERS="$2"     # e.g. "cassandra_b cassandra_c"
VALUE="$3"              # e.g. "40%" or "100ms"
DURATION="$4"           # in seconds
LABEL="$5"              # run label

# 1) Prepare output dir
TS=$(date +"%Y%m%d_%H%M%S")
OUTDIR="outputs/${TS}_${LABEL}"
mkdir -p "$OUTDIR"

echo "[INFO] Mode       : $MODE"
echo "[INFO] Targets    : $RAW_CONTAINERS"
echo "[INFO] Value      : $VALUE"
echo "[INFO] Duration   : ${DURATION}s"
echo "[INFO] Output dir : $OUTDIR"
echo

# 2) Inject netem if requested
if [[ -n "$RAW_CONTAINERS" ]]; then
  for C in $RAW_CONTAINERS; do
    echo "[INFO] Applying $MODE=$VALUE → $C"
    docker exec "$C" tc qdisc del dev eth0 root 2>/dev/null || true
    docker exec "$C" tc qdisc add dev eth0 root netem $MODE $VALUE
  done
  echo "[INFO] Settling 5s…"
  sleep 5
else
  echo "[INFO] No fault injection"
fi

# 3) Run cassandra‑stress
LOGFILE="${LABEL}_cassandra-stress.log"
echo "[INFO] Running cassandra-stress for ${DURATION}s…"
docker exec cassandra_a bash -lc "
  apt-get update -qq &&
  apt-get install -y -qq openjdk-8-jre-headless &&
  exec /opt/cassandra/tools/bin/cassandra-stress write \
    duration=${DURATION}s \
    -node cassandra_a:9042,cassandra_b:9042,cassandra_c:9042 \
    -schema 'replication(factor=3)' \
    -mode native cql3 \
    -rate threads=50 \
    > /tmp/${LOGFILE} 2>&1
"

# 4) Copy out the stress log
docker cp cassandra_a:/tmp/"${LOGFILE}" "$OUTDIR/${LOGFILE}"
echo "[INFO] Stress log → $OUTDIR/${LOGFILE}"

# 5) Save metadata
{
  echo "mode=${MODE}"
  echo "value=${VALUE}"
  echo "duration=${DURATION}"
  date
} > "$OUTDIR/metadata.txt"
echo "[INFO] Metadata → $OUTDIR/metadata.txt"

# 6) Cleanup netem
if [[ -n "$RAW_CONTAINERS" ]]; then
  echo "[INFO] Removing netem…"
  for C in $RAW_CONTAINERS; do
    docker exec "$C" tc qdisc del dev eth0 root 2>/dev/null || true
  done
fi

echo "[SUCCESS] Results in $OUTDIR/"
