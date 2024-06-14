from scapy.all import *
from scapy.layers.inet import UDP
from header_definition import *

def get_if():
    ifs=get_if_list()
    iface=None
    for i in ifs:
        if "eno3" in i:
            iface=i
            break
    if iface==None:
        print("cannot find the interface")
        exit(1)
    return iface
iface=get_if()

def show_details(pkt):
    pkt=bytes(pkt)
    ether = Ether(pkt)
    print("Ethernet Header:")
    print(f"  dst = {ether.dst}")
    print(f"  src = {ether.src}")
    print(f"  type = 0x{ether.type:04x}")

    if ether.type == 2048:
        # IPv4
        ipv4=IP(bytes(ether.payload))
        print(f"IPv4 Header:")
        print(f"  version = {ipv4.version}")
        print(f"  ihl = {ipv4.ihl}")
        print(f"  tos = {ipv4.tos}")
        print(f"  len = {ipv4.len}")
        print(f"  id = {ipv4.id}")
        print(f"  flags = {ipv4.flags}")
        print(f"  frag = {ipv4.frag}")
        print(f"  ttl = {ipv4.ttl}")
        print(f"  proto = {ipv4.proto}")
        print(f"  chksum = {ipv4.chksum}")
        print(f"  src = {ipv4.src}")
        print(f"  dst = {ipv4.dst}")

        if ipv4.proto == 150:
            # INT
            probe_header=probe_t(bytes(ipv4.payload))
            print(f"Probe Header:")
            print(f"  data_cnt = {probe_header.data_cnt}")
            probe_data = probe_data_h(bytes(probe_header.payload))
            for i in range(probe_header.data_cnt):
                #probe_data=probe_data_h(bytes(probe_header.payload))
                print(f"  probe_data={i+1}")
                print(f"  port_ingress={probe_data.port_ingress}")
                print(f"  port_egress={probe_data.port_egress}")
                print(f"  current_time_ingress={probe_data.current_time_ingress}")
                print(f"  packet_cnt_ingress={probe_data.packet_cnt_ingress}")
                print(f"  packet_cnt_egress={probe_data.packet_cnt_egress}")
                print(f"  packet_len_ingress={probe_data.packet_len_ingress}")
                print(f"  packet_len_egress={probe_data.packet_len_egress}")
                probe_data=probe_data_h(bytes(probe_data.payload))

def packet_handler(pkt):
    print("got a packet")
    show_details(pkt)
    #pkt.show2()
    sys.stdout.flush()

def receive_packets():
    print(f"start receiving on {iface}")
    sniff(iface=iface,prn=packet_handler)

receive_packets()
