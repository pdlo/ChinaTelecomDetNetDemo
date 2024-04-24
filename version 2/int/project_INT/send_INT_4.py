#!/usr/bin/env python3
import sys
import time
from scapy.all import get_if_list, get_if_hwaddr, Ether, IPv6, sendp
from headers_definition_4 import *


TYPE_IPV6 = 0x86dd

TYPE_PROBE = 0x0812


def get_if():
    ifs = get_if_list()
    iface = None
    for i in get_if_list():
        if "eth0" in i:
            iface = i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface


def main():
    iface = get_if()
    probe_pkt_1 = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff",type=TYPE_IPV6) / \
                  IPv6(nh=44) / \
                  srv6h(segment_left=3,last_entry=3) / \
                  srv6_list_1(segment_id="0000:0000:0000:0000:0000:0000:0000:0109") / \
                  srv6_list_2(segment_id="0000:0000:0000:0000:0000:0000:0000:0104") / \
                  srv6_list_3(segment_id="0000:0000:0000:0000:0000:0000:0000:0101") / \
                  srv6_list_4(segment_id="0000:0000:0000:0000:0000:0000:0000:0099") / \
                  probe_header(num_probe_data=0)
    '''probe_pkt_2 = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff",type=TYPE_IPV6) / \
                  IPv6(nh=44) / \
                  srv6h(segment_left=4,last_entry=4) / \
                  srv6_list_1(segment_id="0000:0000:0000:0000:0000:0000:0000:0350") / \
                  srv6_list_2(segment_id="0000:0000:0000:0000:0000:0000:0000:0300") / \
                  srv6_list_3(segment_id="0000:0000:0000:0000:0000:0000:0000:0700") / \
                  srv6_list_4(segment_id="0000:0000:0000:0000:0000:0000:0000:0500") / \
                  srv6_list_5(segment_id="0000:0000:0000:0000:0000:0000:0000:0100") / \
                  probe_header(num_probe_data=0)'''
    
   
    while True:
        try:
            probe_pkt_1.show()
     
            sendp(probe_pkt_1, iface=iface)
            '''probe_pkt_2.show()
            sendp(probe_pkt_2, iface=iface)'''
            time.sleep(1)
        except KeyboardInterrupt as e:
            print('Program terminated by user.')
            sys.exit()


if __name__ == '__main__':
    main()
