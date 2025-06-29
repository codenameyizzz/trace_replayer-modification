#!/bin/bash

# Prompt input parameters
read -p "Enter GC interval (ms): " GC_INTERVAL_MS
read -p "Enter burst length (IOs): " BURST_LEN
read -p "Enter delay per IO during burst (us): " DELAY_US

# Path to trace and binary
TRACE_PATH="/home/cc/traces/trace_p100_sample10k_clean.trace"
LOG_DIR="./fsdelay_logs"
BIN="sudo ./io_fsdelay"

# Output log name
LOG_NAME="trace_fsdelay_GCINT${GC_INTERVAL_MS}_BURST${BURST_LEN}_DELAY${DELAY_US}.log"

# Ensure log directory exists
mkdir -p ${LOG_DIR}

# Execute replayer with given config
${BIN} \
    -d /dev/nvme0n1 \
    -f ${TRACE_PATH} \
    -l ${LOG_DIR}/${LOG_NAME} \
    -r 1 \
    -g ${GC_INTERVAL_MS} \
    -b ${BURST_LEN} \
    -y ${DELAY_US}

echo "Finished experiment. Log saved to ${LOG_DIR}/${LOG_NAME}"
