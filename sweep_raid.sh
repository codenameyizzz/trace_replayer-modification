#!/usr/bin/env bash
set -e

if [ $# -lt 4 ]; then
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
LOGDIR=~/sweep_logs/raid_delay_sweep
mkdir -p "$LOGDIR"

gcc io_replayer_raid.c -o io_replayer_raid -lpthread

for DELAY in $(seq $START $STEP $END); do
  echo "▶ Running delay = $DELAY ms"

  LOGFILE=$LOGDIR/trace_raid_D${DELAY}.log
  sudo ./io_replayer_raid /dev/nvme0n1 $TRACE $LOGFILE \
    -d $DELAY -m $OFFSET_START -x $OFFSET_END -r 1
done

echo " Sweep complete. Logs in $LOGDIR"
