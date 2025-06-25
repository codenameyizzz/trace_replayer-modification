#!/usr/bin/env bash
set -e

echo "RAID Tail Amplification - Manual Config"

read -p "Target disk ID (e.g., 2): " DISK_ID
read -p "Injection delay (ms): " DELAY
read -p "Injection start offset (e.g., 0): " START
read -p "Injection end offset (e.g., 500000000): " END

TRACE=~/traces/trace_p100_sample10k_clean.trace
LOGDIR=~/logs
LOGFILE=$LOGDIR/trace_raid_d${DISK_ID}_delay${DELAY}_start${START}_end${END}.log

echo "Building..."
gcc io_replayer_raid.c -o io_replayer_raid -lpthread

echo "Running RAID injection..."
sudo ./io_replayer_raid /dev/nvme0n1 $TRACE $LOGFILE \
  -d $DELAY -m $START -x $END -r 1

echo "✅ Done. Output: $LOGFILE"
