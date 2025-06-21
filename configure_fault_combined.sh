#!/usr/bin/env bash
#
# configure_fault_combined.sh — Run unified fault injection with one io_replayer binary

set -e

# Paths & defaults
REPLAYER_SOURCE=io_replayer_all_combined.c
BINARY=io_replayer
DEVICE=/dev/nvme0n1
TRACE=~/traces/trace_p100_sample100k.trace
LOGDIR=~/logs

# Prompt for fault experiment
echo "Select fault experiment to inject:"
select FAULT in   ftcx_firmware_tail   gc_read_slowness   raid_amplification; do
  [ -n "$FAULT" ] && break
done

# Set fault-specific defines and logtag
EXTRA_DEFS=""
LOGTAG="${FAULT}"
case $FAULT in
  ftcx_firmware_tail)
    read -p "Enter logical disk ID [0–3]: " DISK_ID
    read -p "Enter injection probability (%) [0–100]: " INJECT_PCT
    read -p "Enter duration (I/Os in slow mode): " DURATION
    read -p "Enter min delay per I/O (us): " DELAY_MIN
    read -p "Enter max delay per I/O (us): " DELAY_MAX
    EXTRA_DEFS="
      -DFAULT_FTCX       -DFAULT_DISK_ID=${DISK_ID}       -DFAULT_PROB=${INJECT_PCT}       -DFAULT_DURATION=${DURATION}       -DFAULT_DELAY_MIN_US=${DELAY_MIN}       -DFAULT_DELAY_MAX_US=${DELAY_MAX}"
    LOGTAG="ftcx_d${DISK_ID}_p${INJECT_PCT}_n${DURATION}_l${DELAY_MIN}-${DELAY_MAX}"
    ;;
  gc_read_slowness)
    read -p "Enter injection probability (%) [0–100]: " INJECT_PCT
    read -p "Enter delay per injected READ (us): " DELAY_US
    EXTRA_DEFS="
      -DFAULT_GC       -DFAULT_GC_DELAY_US=${DELAY_US}       -DFAULT_GC_PROB=${INJECT_PCT}"
    LOGTAG="gc_p${INJECT_PCT}_t${DELAY_US}"
    ;;
  raid_amplification)
    read -p "Enter delay (ms): " DELAY_MS
    read -p "Enter offset start (bytes): " OFFSET_START
    read -p "Enter offset end (bytes): " OFFSET_END
    read -p "Request type to inject (0=WRITE, 1=READ, 2=BOTH): " IO_TYPE
    EXTRA_DEFS="
      -DFAULT_RAID       -DFAULT_RAID_DELAY_MS=${DELAY_MS}       -DFAULT_RAID_START=${OFFSET_START}       -DFAULT_RAID_END=${OFFSET_END}       -DFAULT_RAID_TYPE=${IO_TYPE}"
    LOGTAG="raid_d${DELAY_MS}_o${OFFSET_START}-${OFFSET_END}_r${IO_TYPE}"
    ;;
esac

# Output log file path
LOGFILE=${LOGDIR}/trace_${LOGTAG}.log

# Compile
echo "Building ${BINARY} with fault=${FAULT}..."
gcc ${REPLAYER_SOURCE} -o ${BINARY} -lpthread ${EXTRA_DEFS}

# Run
echo "Running ./${BINARY} on ${TRACE} → ${LOGFILE} ..."
sudo ./${BINARY} ${DEVICE} ${TRACE} ${LOGFILE}
echo "Finished. Log: ${LOGFILE}"
