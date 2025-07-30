#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 DELAY_US start step end"
    exit 1
fi

PARAM=$1
START=$2
STEP=$3
END=$4

# Path setup
TRACE="/home/cc/traces/trace_p100_sample10k_clean.trace"
DEVICE="/dev/nvme0n1"
LOG_DIR="./fsdelay_logs"
mkdir -p $LOG_DIR

# Constants
GC_INTERVAL_MS=10
BURST_LEN=100
READ_MODE=1

echo "[*] Compiling io_fsdelay..."
gcc io_fsdelay.c -o io_fsdelay -lpthread

for ((val=$START; val<=$END; val+=$STEP))
do
    echo "=== Running with ${PARAM} = ${val} ==="
    LOG_NAME="trace_fsdelay_GCINT${GC_INTERVAL_MS}_BURST${BURST_LEN}_DELAY${val}.log"
    LOG_PATH="${LOG_DIR}/${LOG_NAME}"

    echo "Logfile: ${LOG_PATH}"
    sudo ./io_fsdelay \
        -f $TRACE \
        -l $LOG_PATH \
        -r $READ_MODE \
        -d $DEVICE \
        -g $GC_INTERVAL_MS \
        -b $BURST_LEN \
        -y $val
done