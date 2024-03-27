#!/usr/bin/env python3
import sys
import time
from scapy.all import get_if_list, get_if_hwaddr, Ether, IPv6, sendp
from src.int.headers_definition import srv6h, srv6_list_1, srv6_list_2, srv6_list_3, srv6_list_4, srv6_list_5, probe_header


TYPE_IPV6 = 0x86dd

TYPE_PROBE = 0x0812


def get_if():
    ifs = get_if_list()
    iface = None
    for i in get_if_list():
        if "eth1" in i:
            iface = i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface


def main():
    iface = get_if()
    probe_pkt_1 = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
                  IPv6(nh=44) / \
                  srv6h(segment_left=5) / \
                  srv6_list_1(segment_id="0000:0185:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_2(segment_id="0000:0187:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_3(segment_id="0000:0181:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_4(segment_id="0000:0183:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_5(segment_id="0000:0189:0000:0000:0000:0000:0000:0000") / \
                  probe_header(num_probe_data=0)
    probe_pkt_2 = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
                  IPv6(nh=44) / \
                  srv6h(segment_left=5) / \
                  srv6_list_1(segment_id="0000:0181:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_2(segment_id="0000:0185:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_3(segment_id="0000:0187:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_4(segment_id="0000:0183:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_5(segment_id="0000:0189:0000:0000:0000:0000:0000:0000") / \
                  probe_header(num_probe_data=0)
                  
    probe_pkt_3 = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
                  IPv6(nh=44) / \
                  srv6h(segment_left=5) / \
                  srv6_list_1(segment_id="0000:0181:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_2(segment_id="0000:0187:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_3(segment_id="0000:0185:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_4(segment_id="0000:0183:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_5(segment_id="0000:0189:0000:0000:0000:0000:0000:0000") / \
                  probe_header(num_probe_data=0)
    probe_pkt_4 = Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
                  IPv6(nh=44) / \
                  srv6h(segment_left=5) / \
                  srv6_list_1(segment_id="0000:0187:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_2(segment_id="0000:0185:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_3(segment_id="0000:0181:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_4(segment_id="0000:0183:0000:0000:0000:0000:0000:0000") / \
                  srv6_list_5(segment_id="0000:0189:0000:0000:0000:0000:0000:0000") / \
                  probe_header(num_probe_data=0)

    while True:
        try:
            probe_pkt_1.show()
            sendp(probe_pkt_1, iface=iface)
            probe_pkt_2.show()
            sendp(probe_pkt_2, iface=iface)
            probe_pkt_3.show()
            sendp(probe_pkt_3, iface=iface)
            probe_pkt_4.show()
            sendp(probe_pkt_4, iface=iface)
            time.sleep(1)
        except KeyboardInterrupt as e:
            print('Program terminated by user.')
            sys.exit()


if __name__ == '__main__':
    main()
