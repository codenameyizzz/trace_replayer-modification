  #!/bin/bash

  # Usage:
  #   ./run_netdelay.sh "cassandra_b cassandra_c" "100ms" 30 delay100ms

  set -euo pipefail

  RAW_CONTAINERS="$1"
  TARGET_CONTAINERS=""
  for C in $RAW_CONTAINERS; do
    TARGET_CONTAINERS="$TARGET_CONTAINERS ${C}"
  done

  DELAY_VALUE="$2"
  DURATION="$3"  # in seconds
  RESULT_DIR="$4"

  echo "[INFO] Target containers     : $TARGET_CONTAINERS"
  echo "[INFO] Delay value           : $DELAY_VALUE"
  echo "[INFO] Duration              : $DURATION seconds"
  echo "[INFO] Result directory      : $RESULT_DIR"

  # Step 1: Inject delay using `tc` inside each target container
  for CONTAINER in $TARGET_CONTAINERS; do
    echo "[INFO] Injecting delay to $CONTAINER..."
    docker exec "$CONTAINER" bash -c "
      apt-get update -qq &&
      apt-get install -y -qq iproute2 net-tools &&
      tc qdisc del dev eth0 root || true &&
      tc qdisc add dev eth0 root netem delay $DELAY_VALUE
    "
  done

  for CONTAINER in $TARGET_CONTAINERS; do
    echo "[DEBUG] tc qdisc show for $CONTAINER:"
    docker exec "$CONTAINER" tc qdisc show
  done

  # Step 2: Wait for cluster stabilization
  echo "[INFO] Waiting 15s for cluster to stabilize after delay..."
  sleep 15

  # Step 2.5: Create result dir BEFORE cassandra-stress
  mkdir -p "results/$RESULT_DIR"

  # Step 3: Run cassandra-stress from cassandra_a to the entire cluster
  echo "[INFO] Running cassandra-stress write test..."


  docker exec cassandra_a bash -c "
    apt-get update -qq &&
    apt-get install -y -qq openjdk-8-jre-headless &&
    /opt/cassandra/tools/bin/cassandra-stress write cl=ONE duration=${DURATION}s \
      -node cassandra_a,cassandra_b,cassandra_c -mode native cql3 -rate threads=50 -col n=FIXED\\(1\\) -schema replication\\(factor=3\\) \
      > /tmp/stress-output.log 2>&1
  "
  docker cp cassandra_a:/tmp/stress-output.log results/$RESULT_DIR/stress-output.log

  # Step 4: Save result markers
  mkdir -p "results/$RESULT_DIR"
  echo "[INFO] Delay $DELAY_VALUE injected to $TARGET_CONTAINERS" > "results/$RESULT_DIR/metadata.txt"
  date > "results/$RESULT_DIR/timestamp.txt"

  # Step 5: Cleanup delay
  for CONTAINER in $TARGET_CONTAINERS; do
    echo "[INFO] Removing delay from $CONTAINER..."
    docker exec "$CONTAINER" tc qdisc del dev eth0 root || true
  done

  echo "[INFO] Experiment complete. Results stored in: results/$RESULT_DIR"
