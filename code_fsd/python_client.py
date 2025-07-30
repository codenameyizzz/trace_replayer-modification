import sys
sys.path.append('/home/cc/osfn_fd/charybdefs/gen-py')

from server import server
from server.ttypes import *

from thrift import Thrift
from thrift.transport import TSocket
from thrift.transport import TTransport
from thrift.protocol import TBinaryProtocol

def str_to_bool(s):
    return s.lower() in ['true', '1', 'yes']

try:
    transport = TSocket.TSocket('127.0.0.1', 9090)
    transport = TTransport.TBufferedTransport(transport)
    protocol = TBinaryProtocol.TBinaryProtocol(transport)
    client = server.Client(protocol)
    transport.open()

    if len(sys.argv) == 1:
        print(client.get_methods())

    elif sys.argv[1] == "set_fault":
        method = [sys.argv[2]]
        random = str_to_bool(sys.argv[3])
        err_no = int(sys.argv[4])
        probability = int(sys.argv[5])
        regexp = sys.argv[6]
        kill = str_to_bool(sys.argv[7])
        delay_us = int(sys.argv[8])
        auto_delay = str_to_bool(sys.argv[9])

        print("[DEBUG] Set fault with:")
        print("  method =", method)
        print("  random =", random)
        print("  err_no =", err_no)
        print("  probability =", probability)
        print("  regexp =", regexp)
        print("  kill =", kill)
        print("  delay_us =", delay_us)
        print("  auto_delay =", auto_delay)

        client.set_fault(method, random, err_no, probability, regexp, kill, delay_us, auto_delay)

    elif sys.argv[1] == "clear_all_faults":
        client.clear_all_faults()

except Thrift.TException as tx:
    print('%s' % tx.message)
