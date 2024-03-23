from scapy.all import Packet,ByteField,BitField,IntField,IP6Field,bind_layers

TYPE_PROBE = 0x0812
TYPE_IPV6 = 0x86dd

class probe_header(Packet):
   fields_desc = [ ByteField("num_probe_data", 0)]

class probe_data(Packet):
   fields_desc = [ 
                   BitField("swid", 0, 8),
                   BitField("ingress_port", 0, 8),
                   BitField("egress_port", 0, 8),
                   IntField("ingress_byte_cnt", 0),
                   IntField("egress_byte_cnt", 0),
                   BitField("ingress_last_time",0,48),
                   BitField("ingress_cur_time",0, 48),
                   BitField("egress_last_time", 0, 48),
                   BitField("egress_cur_time", 0, 48),
                   IntField("ingress_packet_count", 0),
                   IntField("egress_packet_count", 0)]


'''class ipv6(Packet):
   fields_desc = [ 
                   BitField("version", 0, 4),
                   BitField("traffic_class", 0, 8),
                   BitField("flow_label", 0, 20),
                   BitField("payload_len", 0,16),
                   BitField("next_hdr", 0,8),
                   BitField("hop_limit",0,8),
                   BitField("src_addr",0, 128),
                   BitField("dst_addr", 0, 128)]'''


class srv6h(Packet):
   fields_desc = [ 
                   BitField("next_hdr", 0, 8),
                   BitField("hdr_ext_len", 0, 8),
                   BitField("routing_type", 0, 8),
                   BitField("segment_left", 0, 8),
                   BitField("last_entry", 0, 8),
                   BitField("flags", 0, 8),
                   BitField("tag", 0, 16)
                   ]


class srv6_list_1(Packet):
   fields_desc = [IP6Field("segment_id", "::")]
class srv6_list_2(Packet):
   fields_desc = [IP6Field("segment_id", "::")]
class srv6_list_3(Packet):
   fields_desc = [IP6Field("segment_id", "::")]
class srv6_list_4(Packet):
   fields_desc = [IP6Field("segment_id", "::")]
class srv6_list_5(Packet):
   fields_desc = [IP6Field("segment_id", "::")]

bind_layers(Ether, probe_header, type=TYPE_PROBE)
bind_layers(Ether, IPv6, type=TYPE_IPV6)
bind_layers(IPv6, srv6h)
bind_layers(probe_header, probe_data)
bind_layers(probe_data, probe_data)
bind_layers(srv6h, srv6_list_1)
bind_layers(srv6_list_1, srv6_list_2)
bind_layers(srv6_list_2, srv6_list_3)
bind_layers(srv6_list_3, srv6_list_4)
bind_layers(srv6_list_4, srv6_list_5)
bind_layers(srv6_list_5,probe_header)

"""bind_layers(Ether, IPv6, type=TYPE_IPV6)
bind_layers(IPv6, srv6h)
bind_layers(srv6h,srv6_list_1 )
bind_layers(srv6_list_1, srv6_list_2)
bind_layers(srv6_list_2, srv6_list_3)
bind_layers(srv6_list_3, srv6_list_4)
bind_layers(srv6_list_4, srv6_list_5)
bind_layers(srv6_list_5,probe_header)
bind_layers(probe_header, probe_data)
bind_layers(probe_data, probe_data)"""
