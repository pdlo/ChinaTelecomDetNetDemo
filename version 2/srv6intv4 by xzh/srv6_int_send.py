#!/usr/bin/env python3

from scapy.all import *
import sys
import time
from ipaddress import ip_address

class ProbeEth(Packet):
   fields_desc = [ BitField("dst_mac", 0, 48),
                   BitField("src_mac", 0, 48),
                   BitField("ether_type", 0, 16)
                   ]

class ProbeIPv6(Packet):
   fields_desc = [ BitField("version", 0, 4),
                   BitField("traffic_class", 0, 8),
                   BitField("flow_label", 0, 20),
                   BitField("payload_len", 0, 16),
                   BitField("next_hdr", 0, 8),
                   BitField("hop_limit", 0, 8),
                   BitField("src_ipv6", 0, 128),
                   BitField("dst_ipv6", 0, 128)
                   ]

class ProbeSRv6(Packet):
   fields_desc = [ BitField("next_hdr", 0, 8),
                   BitField("hdr_ext_len", 0, 8),
                   BitField("routing_type", 0, 8),
                   BitField("segment_left", 0, 8),
                   BitField("last_entry", 0, 8),
                   BitField("flags", 0, 8),
                   BitField("tag", 0, 16)
                   ]

class ProbeSRv6list(Packet):
   fields_desc = [ BitField("segment_id", 0, 128)
                  ]

class Probeh(Packet):
   fields_desc = [ BitField("data_cnt", 0, 8)
                  ]


# 发送数据包的函数
def send_probe_pkt(src_net_card, segment_left, last_entry, s):
    # probe_pkt = ProbeEth(dst_mac="ff:ff:ff:ff:ff:ff", src_mac=get_if_hwaddr(src_net_card), ether_type=2054)
    dst_mac = "ff:ff:ff:ff:ff:ff"
    src_mac = "a0:36:9f:d5:24:92"
    probe_pkt = ProbeEth(dst_mac=int(dst_mac.replace(':', ''), 16), src_mac=int(src_mac.replace(':', ''), 16), ether_type=int('86dd', 16))
    dst_ipv6 = "0000:0151:0000:0000:0000:0000:0000:0000"
    src_ipv6 = "0000:0182:0000:0000:0000:0000:0000:0000"
    probe_pkt /= ProbeIPv6(version=6, payload_len = 188, next_hdr=43, hop_limit=6, src_ipv6=int(src_ipv6.replace(':', ''), 16), dst_ipv6=int(dst_ipv6.replace(':', ''), 16))
    probe_pkt /= ProbeSRv6(next_hdr=200, hdr_ext_len=88, routing_type=4, segment_left=segment_left, last_entry=last_entry)
    for i in range(last_entry+1):
        probe_pkt /= ProbeSRv6list(segment_id=int(s[i].replace(':', ''), 16))
    probe_pkt /= Probeh(data_cnt=0)

    print("whole: %s" %(probe_pkt))

    sendp(probe_pkt, iface=src_net_card)


def main():
    # send_probe_pkt('Inter(R) Wireless-AC 9462', 3, 3, ["0000:0151:0000:0000:0000:0000:0000:0000", "0000:0152:0000:0000:0000:0000:0000:0000", "0000:0152:0000:0000:0000:0000:0000:0000", "0000:0188:0000:0000:0000:0000:0000:0000"])
    while 1:
        send_probe_pkt('unused', 3, 3, ["0000:0188:0000:0000:0000:0000:0000:0000", "0000:0153:0000:0000:0000:0000:0000:0000", "0000:0152:0000:0000:0000:0000:0000:0000", "0000:0151:0000:0000:0000:0000:0000:0000"])
        time.sleep(1)
    # while True:
    #     try:
    #         # 发送第一个路径的数据包
    #         send_probe_pkt('Inter(R) Wireless-AC 9462', 3, 3, ["0000:0151:0000:0000:0000:0000:0000:0000", "0000:0152:0000:0000:0000:0000:0000:0000", "0000:0152:0000:0000:0000:0000:0000:0000", "0000:0188:0000:0000:0000:0000:0000:0000"])
    #         time.sleep(1)

    #         """# 发送第二个路径的数据包
    #         send_probe_pkt(6, [1, 2, 5, 3, 1, 0])
    #         time.sleep(1)"""

    #         """# 发送第三个路径的数据包
    #         send_probe_pkt(6, [3, 4, 4, 1, 4, 1, 1, 0])
    #         time.sleep(1)"""

    #     except KeyboardInterrupt:
    #         sys.exit()

if __name__ == '__main__':
    main()

