#!/usr/bin/env bash
#
# sweep_experiment.sh: one-factor sweep for a single fault
#
# Usage:
#   ./sweep_experiment.sh FAULT PARAM START STEP END [KEY=VAL ...]
#
# Example:
#   ./sweep_experiment.sh firmware_bug_random RANDOM_MAX_DELAY_MS 10 10 100 \
#     INJECT_PCT=5 RANDOM_MAX_RETRIES=2

set -e

if [ $# -lt 5 ]; then
  echo "Usage: $0 FAULT PARAM START STEP END [KEY=VAL ...]"
  exit 1
fi

FAULT=$1           # e.g. firmware_bug_random
PARAM=$2           # the #define to sweep, e.g. RANDOM_MAX_DELAY_MS
START=$3           # first value, e.g. 10
STEP=$4            # step increment, e.g. 10
END=$5             # last value, e.g. 100
shift 5

# Map the fault name to the actual compile‐time symbol in your C code
declare -A FAULTSYM=(
  [media_retries]=FAULT_MEDIA_RETRIES
  [firmware_bug_random]=FAULT_FW_RANDOM
  [raid_tail]=RAID_TAIL_FAKE_SYMBOL
  [gc_pause]=FAULT_GC_PAUSE
  [gc_slowness]=FAULT_GC_SLOW
  [mlc_variability]=FAULT_MLC_VAR
  [ecc_read_retry]=FAULT_ECC_RETRY
  [firmware_bandwidth_drop]=FAULT_FW_BW_DROP
  [voltage_read_retry]=FAULT_VOLTAGE_RETRY
  [firmware_throttle]=FAULT_FW_THROTTLE
  [wear_pathology]=FAULT_WEAR_PATHOLOGY
  [firmware_tail]=FAULT_FW_TAIL
)

SYM=${FAULTSYM[$FAULT]}
if [ -z "$SYM" ]; then
  echo "Unknown fault '$FAULT'"
  exit 1
fi

# collect any extra KEY=VAL pairs
EXTRA_DFLAGS=()
for kv in "$@"; do
  KEY=${kv%%=*}
  VAL=${kv#*=}
  EXTRA_DFLAGS+=( "-D${KEY}=${VAL}" )
done

SWEEP_DIR=~/sweep_logs/${FAULT}_sweep_${PARAM}
mkdir -p "$SWEEP_DIR"

echo "▶ sweeping $FAULT via $PARAM from $START..$END by $STEP"

if [[ "$FAULT" == "raid_tail" ]]; then
  SWEEP_DIR=~/sweep_logs/${FAULT}_sweep_${PARAM}
  mkdir -p "$SWEEP_DIR"
  echo "▶ Sweeping RAID fault via $PARAM from $START..$END by $STEP"
  for v in $(seq "$START" "$STEP" "$END"); do
    echo
    echo "→ [$PARAM=$v]"

    EXTRA_ARGS=""
    for kv in "$@"; do
      KEY="${kv%%=*}"
      VAL="${kv#*=}"
      if [[ "$KEY" == "$PARAM" ]]; then
        VAL="$v"
      fi

      # Explicit key-to-flag mapping (optional)
      case "$KEY" in
        INJECTION_DELAY) FLAG="-d" ;;
        INJECTION_START) FLAG="-m" ;;
        INJECTION_END)   FLAG="-x" ;;
        INJECTION_TYPE)  FLAG="-r" ;;
        *) FLAG="-${KEY:0:1}" ;;  # fallback
      esac
      EXTRA_ARGS+=" ${FLAG} ${VAL}"
    done

    LOGFILE="${SWEEP_DIR}/trace_raid_${PARAM}${v}.log"
    echo "   Running → ${LOGFILE}"
    sudo ./io_repcopy /dev/nvme0n1 ~/traces/trace_p100_sample10k_clean.trace "${LOGFILE}" ${EXTRA_ARGS}
  done

  echo
  echo " RAID sweep complete: logs in ${SWEEP_DIR}"
  exit 0
fi

if [[ "$FAULT" == "gc_slowness" ]]; then
  SWEEP_DIR=~/sweep_logs/${FAULT}_sweep_${PARAM}
  mkdir -p "$SWEEP_DIR"
  echo "▶ Sweeping GC fault via $PARAM from $START..$END by $STEP"

  for v in $(seq "$START" "$STEP" "$END"); do
    echo
    echo "→ [$PARAM=$v]"

    EXTRA_ARGS=""
    for kv in "$@"; do
      KEY="${kv%%=*}"
      VAL="${kv#*=}"
      if [[ "$KEY" == "$PARAM" ]]; then
        VAL="$v"
      fi

      # Mapping keys to CLI args
      case "$KEY" in
        GC_PROB)      FLAG="--gc-prob" ;;
        GC_DELAY_US)  FLAG="--gc-delay" ;;
        *)            FLAG="--${KEY,,}" ;;  # fallback to lowercase flag
      esac
      EXTRA_ARGS+=" ${FLAG} ${VAL}"
    done

    LOGFILE="${SWEEP_DIR}/trace_gc_${PARAM}${v}.log"
    echo "   Running → ${LOGFILE}"
    sudo ./io_repcopy /dev/nvme0n1 ~/traces/trace_p100_sample10k_clean.trace "${LOGFILE}" ${EXTRA_ARGS}
  done

  echo
  echo "GC sweep complete: logs in ${SWEEP_DIR}"
  exit 0
fi


for v in $(seq "$START" "$STEP" "$END"); do
  echo
  echo "→ [$PARAM=$v]"
  # compile with the right FAULT_xxx and the PARAM set to $v
  gcc io_repcopy.c -o io_repcopy -lpthread \
      -D${SYM} -D${PARAM}=${v} "${EXTRA_DFLAGS[@]}"

  LOGFILE="${SWEEP_DIR}/trace_p100_sample10k_clean_${FAULT}_${PARAM}${v}.log"
  echo "   Running → ${LOGFILE}"
  sudo ./io_repcopy /dev/nvme0n1 ~/traces/trace_p100_sample10k_clean.trace "${LOGFILE}"
done

echo
echo "Sweep complete: logs in ${SWEEP_DIR}"

