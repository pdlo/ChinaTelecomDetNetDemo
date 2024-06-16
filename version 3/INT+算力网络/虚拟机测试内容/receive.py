from scapy.all import *
from scapy.layers.inet import UDP
#from header_definition import *
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
def packet_handler(pkt):
    print("received a packet:")
    pkt.show()
    sys.stdout.flush()
def receive_packets():
    print(f"start receiving on {iface}")
    sniff(iface=iface,prn=packet_handler)


receive_packets()
