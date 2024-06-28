from scapy.fields import BitField, IP6Field
from scapy.layers.inet import IP, ICMP, UDP, TCP
from scapy.layers.inet6 import IPv6
from scapy.layers.l2 import Ether
from scapy.packet import Packet, bind_layers

class probe_t(Packet):
    name = "probe"
    fields_desc = [
        BitField('data_cnt', 0, 8)
    ]

class probe_data_h(Packet):
    name = "probe_data"
    fields_desc = [
        BitField('port_ingress', 0, 8),
        BitField('port_egress', 0, 8),
        BitField('current_time_ingress', 0, 48),
        BitField('packet_cnt_ingress', 0, 16),
        BitField('packet_cnt_egress', 0, 16),
        BitField('packet_len_ingress', 0, 16),
        BitField('packet_len_egress', 0, 16),
    ]
bind_layers(Ether,IP,type=0x0800)
bind_layers(IP,probe_t,proto=150)
bind_layers(probe_t,probe_data_h)
bind_layers(probe_data_h,probe_data_h)
