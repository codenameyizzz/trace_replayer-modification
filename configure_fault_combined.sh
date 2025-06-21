
#!/bin/bash

set -e

echo "Select fault to inject:"
echo " 1) media_retries              4) mlc_variability           7) voltage_read_retry       10) ftcx_firmware_tail"
echo " 2) firmware_bug_random        5) ecc_read_retry            8) firmware_throttle        11) gc_read_slowness"
echo " 3) gc_pause                   6) firmware_bandwidth_drop   9) wear_pathology           12) raid_amplification"
read -p "#? " choice

# If TRACE file passed as arg
if [ ! -z "$1" ]; then
  TRACE="$1"
else
  read -p "Enter full path to trace file: " TRACE
fi

DEV=/dev/nvme2n1
OUT="log_fault_combined.log"
REPLAYER="./io_replayer_combined"

case $choice in
  10)  # FTCX - Firmware Tail
    read -p "Target disk id (0~3): " target_disk
    read -p "Probability (e.g., 5): " prob
    read -p "Delay min (us): " delay_min
    read -p "Delay max (us): " delay_max
    read -p "Slow mode duration (IO count): " duration
    echo "Building io_replayer with FTCX config..."
    gcc -DFAULT_FTCX -o io_replayer_combined io_replayer.c -lpthread
    sudo $REPLAYER -d $DEV -t $TRACE -o $OUT --target $target_disk --prob $prob --delay_min $delay_min --delay_max $delay_max --duration $duration
    ;;

  11)  # GC - GC Read Slowness
    read -p "Injection delay (us): " delay
    read -p "Probability (e.g., 5): " prob
    echo "Building io_replayer with GC config..."
    gcc -DFAULT_GC -o io_replayer_combined io_replayer.c -lpthread
    sudo $REPLAYER -d $DEV -t $TRACE -o $OUT --delay_us $delay --prob $prob
    ;;

  12)  # RAID Amplification
    read -p "Enter delay (ms): " delay
    read -p "Enter offset start (bytes): " start
    read -p "Enter offset end (bytes): " end
    read -p "Request type to inject (0=WRITE, 1=READ, 2=BOTH): " type
    echo "Building io_replayer with RAID config..."
    gcc -DFAULT_RAID -o io_replayer_combined io_replayer.c -lpthread
    sudo $REPLAYER -d $DEV -t $TRACE -o $OUT --raid_delay $delay --raid_start $start --raid_end $end --raid_type $type
    ;;

  *) echo "Invalid selection"; exit 1;;
esac
