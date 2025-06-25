#!/usr/bin/env bash
set -e

if [ $# -lt 5 ]; then
  echo "Usage: $0 START STEP END OFFSET_START OFFSET_END"
  echo "Example: ./sweep_raid.sh 5 5 50 0 1000000000"
  exit 1
fi

START=$1
STEP=$2
END=$3
OFFSET_START=$4
OFFSET_END=$5

TRACE=~/traces/trace_p100_sample10k_clean.trace
DEVICE=/dev/nvme0n1
LOGDIR=~/sweep_logs/raid_delay_sweep
mkdir -p "$LOGDIR"

echo "Building..."
gcc io_replayer_raid.c -o io_replayer_raid -lpthread

for DELAY in $(seq $START $STEP $END); do
  echo "▶ Running delay = $DELAY ms"

  LOGFILE=$LOGDIR/trace_raid_d${DELAY}_start${OFFSET_START}_end${OFFSET_END}.log
  sudo ./io_replayer_raid \
    -d 2 \
    -r 1 \
    -s $DELAY \
    -m $OFFSET_START \
    -x $OFFSET_END \
    $DEVICE $TRACE $LOGFILE
done

echo " Sweep complete. Logs in $LOGDIR"
