#!/usr/bin/env python3
import sys
import struct
import os

from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet, IPOption
from scapy.all import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField
from scapy.all import IP, TCP, UDP, Raw
from scapy.layers.inet import _IPOption_HDR
from headers_definition_4 import *
def get_if():
    ifs = get_if_list()
    iface = None
    for i in ifs:
        if "eth0" in i:
            iface = i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface


def handle_pkt(pkt):
    print("got a packet")
    pkt.show2()  # Ensure the packet is dissected before accessing its layers.

    sys.stdout.flush()




def main():
    ifaces = [i for i in os.listdir('/sys/class/net/') if 'eth' in i]
    iface = ifaces[0] if ifaces else None
    if iface:
        print(f"sniffing on {iface}")
        sys.stdout.flush()
        sniff(iface=iface, prn=lambda x: handle_pkt(x))
    else:
        print("No suitable interface found.")

if __name__ == '__main__':
    main()

