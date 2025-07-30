#!/bin/bash

set -e

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <targets> <delay> <duration> <outdir-name>"
  echo "Example: $0 \"cassandra_b cassandra_c\" 100ms 30 delay100ms_bc"
  exit 1
fi

TARGETS="$1"
DELAY="$2"
DURATION="$3"
OUTDIR="results/$4"

echo "[INFO] Activating blockade virtualenv..."
source ~/blockade-venv/bin/activate

echo "[INFO] Cleaning up old containers and networks..."
docker rm -f $(docker ps -aq) > /dev/null 2>&1 || true
docker volume prune -f > /dev/null
blockade destroy || true

echo "[INFO] Starting fresh Cassandra cluster via blockade..."
blockade up
sleep 10

blockade status

# Ambil IP tiap node dari blockade
NODE_A_IP=$(blockade status | awk '$1 == "cassandra_a" {print $4}')
NODE_B_IP=$(blockade status | awk '$1 == "cassandra_b" {print $4}')
NODE_C_IP=$(blockade status | awk '$1 == "cassandra_c" {print $4}')

echo "[INFO] Waiting for Cassandra ports to be ready..."

for IP in $NODE_A_IP $NODE_B_IP $NODE_C_IP; do
  echo -n "  Waiting for $IP:9042 "
  while ! docker run --rm --network=bridge busybox sh -c "nc -z -w1 $IP 9042"; do
    echo -n "."
    sleep 2
  done
  echo " OK"
done

echo "[INFO] Injecting delay: $DELAY to nodes: $TARGETS"
for NODE in $TARGETS; do
  echo "[INFO] Running 'blockade slow $NODE $DELAY'..."
  blockade slow $NODE $DELAY
done

echo "[INFO] Verifying tc configuration..."
mkdir -p "$OUTDIR"
for NODE in $TARGETS; do
  CID=$(blockade status | awk -v n=$NODE '$1 == n {print $2}')
  docker exec "$CID" tc qdisc show dev eth0 > "$OUTDIR/tc-$NODE.txt" || true
done

echo "[INFO] Waiting 60s for Cassandra nodes to join cluster..."
sleep 60

echo "[INFO] Running cassandra-stress workload..."

STRESS_CONTAINER=$(blockade status | awk '$1 == "cassandra_a" {print $2}')

CMD=(
  /opt/cassandra/tools/bin/cassandra-stress write
  cl=QUORUM
  duration="${DURATION}s"
  -node ${NODE_A_IP}:9042,${NODE_B_IP}:9042,${NODE_C_IP}:9042
  -mode native cql3
  -col "n=FIXED(1)"
  -rate threads=100
  -schema "replication(factor=3)"
)

echo "[DEBUG] Final CMD array: ${CMD[*]}"
docker exec "$STRESS_CONTAINER" "${CMD[@]}" | tee "$OUTDIR/stress-output.txt"

echo "[INFO] Capturing blockade status..."
blockade status > "$OUTDIR/blockade-status.txt"

echo "[INFO] Done. Results stored in: $OUTDIR"
