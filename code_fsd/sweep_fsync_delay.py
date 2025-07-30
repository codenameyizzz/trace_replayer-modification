import os
import time
import subprocess
import sys

sys.path.append('/home/cc/osfn_fd/charybdefs/gen-py')

from server import server
from server.ttypes import *
from thrift.transport import TSocket, TTransport
from thrift.protocol import TBinaryProtocol

# === Setup Thrift client ===
transport = TSocket.TSocket('127.0.0.1', 9090)
transport = TTransport.TBufferedTransport(transport)
protocol = TBinaryProtocol.TBinaryProtocol(transport)
client = server.Client(protocol)
transport.open()

# === Sweep delays in microseconds ===
delays_us = [1000, 5000, 10000, 50000, 100000, 500000, 1000000]

# === Prepare result file ===
with open("fsync_sweep_results.txt", "w") as f:
    for delay in delays_us:
        print(f"\n=== Injecting {delay/1000:.1f} ms delay on fsync ===")
        client.clear_all_faults()
        client.set_fault(
            ['fsync', 'flush', 'fsyncdir'],  # method
            False,                           # random
            0,                               # errno
            100000,                          # probability (100%)
            "",                              # regex
            False,                           # kill_caller
            delay,                           # delay_us
            True                             # manual_delay
        )

        # === Measure fsync latency ===
        start = time.time()
        subprocess.run([
            "python3", "-c",
            'import os; f = open("/home/cc/fuse_mount/test.txt", "a"); f.write("x"); f.flush(); os.fsync(f.fileno())'
        ])
        end = time.time()

        duration = end - start
        print(f"Duration: {duration:.6f} seconds")
        f.write(f"{delay},{duration:.6f}\n")