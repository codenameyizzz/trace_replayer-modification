#!/bin/bash

# Usage: ./sweep_fsdelay.sh [param_name] [start] [step] [end]
# Example: ./sweep_fsdelay.sh GC_INTERVAL 100 100 500

PARAM="$1"
START="$2"
STEP="$3"
END="$4"

# Fixed values (adjust if sweeping others)
BURST_LEN=10
DELAY_US=100000
GC_INTERVAL=500

TRACE_PATH="../traces/trace_p100_sample10k_clean.trace"
BIN="./io_fsdelay"
LOG_DIR="./fsdelay_logs_sweep"
mkdir -p ${LOG_DIR}

for VAL in $(seq ${START} ${STEP} ${END}); do
    echo "Running with ${PARAM} = ${VAL}"

    # Assign values based on sweep param
    case "$PARAM" in
        GC_INTERVAL)
            GC_INTERVAL=$VAL ;;
        BURST_LEN)
            BURST_LEN=$VAL ;;
        DELAY_US)
            DELAY_US=$VAL ;;
        *)
            echo "Unknown param: $PARAM"
            exit 1 ;;
    esac

    LOG_NAME="trace_fsdelay_${PARAM}${VAL}_GCINT${GC_INTERVAL}_BURST${BURST_LEN}_DELAY${DELAY_US}.log"

    ${BIN} -f ${TRACE_PATH} \
           -l ${LOG_DIR}/${LOG_NAME} \
           -m 0 -r 1 -d /dev/null \
           -g ${GC_INTERVAL} \
           -b ${BURST_LEN} \
           -y ${DELAY_US}
done

echo "All sweep runs completed. Logs stored in ${LOG_DIR}"
