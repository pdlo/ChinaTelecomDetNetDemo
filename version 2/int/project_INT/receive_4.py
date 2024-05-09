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

    # 确定数据包的总长度
    packet_length = len(pkt)
    
    # 确定包含两个 probe_data 实例的数据开始的位置
    start_of_probe_data = packet_length - 42  # 两个 probe_data 实例总共占42字节

    # 获取这42字节的数据
    probe_data_bytes = raw(pkt)[start_of_probe_data:]

    # 处理每个 probe_data 实例
    for i in range(2):  # 两个 probe_data 实例
        # 计算当前 probe_data 实例的起始和结束位置
        start = i * 21  # 每个 probe_data 实例占21字节
        end = start + 21

        # 从数据中提取当前 probe_data 实例的字节串
        current_probe_data_bytes = probe_data_bytes[start:end]

        # 将字节串解析为 probe_data 实例
        probe_data_instance = parse_probe_data(current_probe_data_bytes)

        # 打印或处理每个 probe_data 实例
        print(f"Probe Data {i + 1}:")
        probe_data_instance.show2()

    sys.stdout.flush()

def parse_probe_data(data_bytes):
    # 根据 probe_data 的结构解析 data_bytes
    # 以下是基于你提供的 probe_data 结构的示例解析代码
    swid = int.from_bytes(data_bytes[0:1], byteorder='big')
    byte_cnt = int.from_bytes(data_bytes[1:5], byteorder='big')
    packet_cnt = int.from_bytes(data_bytes[5:9], byteorder='big')
    last_time = int.from_bytes(data_bytes[9:15], byteorder='big')
    cur_time = int.from_bytes(data_bytes[15:21], byteorder='big')

    # 返回一个填充了解析数据的 probe_data 实例
    return probe_data(swid=swid, byte_cnt=byte_cnt, packet_cnt=packet_cnt, last_time=last_time, cur_time=cur_time)



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
