
import time
from scapy.arch import get_if_hwaddr
from scapy.interfaces import get_if_list
from scapy.layers.inet import IP, UDP, ICMP, TCP
from scapy.layers.inet6 import IPv6, ICMPv6EchoRequest
from scapy.layers.l2 import Ether
from scapy.packet import Raw
from scapy.sendrecv import send, sendp
from header_definition import *  # 确保你正确导入了定义

def get_if():
    ifs=get_if_list()
    iface=None
    for i in ifs:
        if "eth0" in i:
            iface=i
            break
    if iface==None:
        print("cannot find the interface")
        exit(1)
    return iface
iface=get_if()

def send_ipv4_icmp():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/
            IP(src='10.0.0.1',dst='10.0.0.2')/ICMP())
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_ipv4_udp():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/
            IP(src='10.0.0.1',dst='10.0.0.2')/UDP())
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_ipv4_tcp():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/
            IP(src='127.0.0.1',dst='127.0.0.1')/TCP())
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_ipv6_icmp():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/
            IPv6(src='::100',dst='::200')/ICMPv6EchoRequest())
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_ipv6_udp():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/
            IPv6(src='::100',dst='::200')/UDP())
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_ipv6_tcp():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/
            IPv6(src='::100',dst='::200')/TCP())
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_ipv4_INT():
    packet=Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/IP(src='127.0.0.1',dst='127.0.0.1',tos=1)/ \
            probe_t(data_cnt=0)
    while True:
        packet.show()
        sendp(packet, iface=iface)
        time.sleep(1)
def send_ipv4_INT_INTDATA():#这个包是为了检测接收端能不能正确解析携带数据的INT包，发送端不会发送在这个包
    packet = Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff") / IP(src='127.0.0.1', dst='127.0.0.1', tos=1) / \
             probe_t(data_cnt=0)/probe_data_h(port_ingress=1,port_egress=2,current_time_ingress=10,packet_cnt_ingress=15,
                                              packet_cnt_egress=20,packet_len_ingress=100,packet_len_egress=200)/ \
             probe_data_h(port_ingress=1, port_egress=2, current_time_ingress=10, packet_cnt_ingress=15,
                          packet_cnt_egress=20, packet_len_ingress=100, packet_len_egress=200)
    while True:
        packet.show()
        sendp(packet, iface=iface)
        time.sleep(1)
send_ipv4_INT()   #具体发哪个包
