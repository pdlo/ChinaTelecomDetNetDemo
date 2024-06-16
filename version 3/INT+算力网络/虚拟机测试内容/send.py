
import time
from scapy.arch import get_if_hwaddr
from scapy.interfaces import get_if_list
from scapy.layers.inet import IP, UDP, ICMP, TCP
from scapy.layers.inet6 import IPv6, ICMPv6EchoRequest
from scapy.layers.l2 import Ether
from scapy.packet import Raw
from scapy.sendrecv import send, sendp
#from header_definition import *  # 确保你正确导入了定义

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
def send_normal_c():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/\
            IPv6(dst='2000::251')/TCP(dport=8001))
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_normal_s():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/\
            IPv6(dst='2000::152')/TCP(dport=8001))
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)

def send_c2s():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/\
            IPv6(dst='2004:06cc:1211:0cba:1c32:fc2b:7cbf:00c3')/TCP(dport=9003))
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)
def send_s2c():
    packet=(Ether(src=get_if_hwaddr(iface),dst="ff:ff:ff:ff:ff:ff")/\
            IPv6(dst='2000::152')/TCP(dport=9003))
    while True:
        packet.show()
        sendp(packet,iface=iface)
        time.sleep(1)


def sendroute1():
    packet = (Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
              IPv6(dst='2004:0522:bac2:2ce3:b1a4:c2ef:ff2c:0ac1') / TCP(dport=9001))
    while True:
        packet.show()
        sendp(packet, iface=iface)
        time.sleep(1)
def sendroute2():
    packet = (Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
              IPv6(dst='2004:05b1:b5ea:aa1c:2104:efff:cf03:bc02') / TCP(dport=9002))
    while True:
        packet.show()
        sendp(packet, iface=iface)
        time.sleep(1)

def sendroute3():
    packet = (Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
              IPv6(dst='2000::152') / TCP(dport=9001))
    while True:
        packet.show()
        sendp(packet, iface=iface)
        time.sleep(1)
def sendroute4():
    packet = (Ether(src=get_if_hwaddr(iface), dst="ff:ff:ff:ff:ff:ff") / \
              IPv6(dst='2000::152') / TCP(dport=9002))
    while True:
        packet.show()
        sendp(packet, iface=iface)
        time.sleep(1)
sendroute3()
