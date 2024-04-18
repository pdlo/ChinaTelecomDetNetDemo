#!/usr/bin/env python3
from scapy.all import *
import sys
import time

TYPE_PROBE = 0x0812
TYPE_IPV4 = 0x0800
def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface


def main():
    #probe_pkt = Ether(dst='ff:ff:ff:ff:ff:ff', src=get_if_hwaddr('eth0'), type=TYPE_IPV4) / \
     #           pro
     
    iface = get_if()
                
    probe_pkt = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff",type=TYPE_IPV4) / IP(src='21.156.182.2', dst='21.158.188.2') / TCP(dport=100)

    while True:
        try:
            probe_pkt.show()
            sendp(probe_pkt, iface=iface)
            time.sleep(0.5)
        except KeyboardInterrupt as e:
            print('Program terminated by user.')
            sys.exit()


if __name__ == '__main__':
    main()
