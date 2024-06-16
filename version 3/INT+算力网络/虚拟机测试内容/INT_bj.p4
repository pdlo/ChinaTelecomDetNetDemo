/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define MAX_PORTS 255
#define MAX_HOPS 5

const bit<16> ETH_TYPE_IPV4 = 0x0800;
const bit<16> ETH_TYPE_IPV6 = 0x86dd;
const bit<16> ETH_TYPE_ARP = 0x0806;

const bit<8>  IP_PROTO_ICMP = 1;
const bit<8>  IP_PROTO_TCP = 6;
const bit<8>  IP_PROTO_UDP = 17;
const bit<8>  IP_PROTO_INT = 150;
const bit<8>  IP_PROTO_TUNNEL = 160;
/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/
header ethernet_t {
    bit<48> dst_mac;
    bit<48> src_mac;
    bit<16> ether_type;
}

header arp_h {
    bit<16>  hardware_type;
    bit<16>  protocol_type;
    bit<8>   HLEN;
    bit<8>   PLEN;
    bit<16>  OPER;
    bit<48>  sender_ha;
    bit<32>  sender_ip;
    bit<48>  target_ha;
    bit<32>  target_ip;
}

header ipv6_t {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_len;  //记录载荷长（包括srh长度）
    bit<8>   next_hdr;  //IPV6基本报头后的那一个扩展包头的信息类型，SRH定为43
    bit<8>   hop_limit;
    bit<128> src_ipv6;
    bit<128> dst_ipv6;
}  //需要ipv6的某一个字段来判断扩展头是否为srv6扩展头

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   total_len;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   frag_offset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdr_checksum;
    bit<32>   src_ipv4;
    bit<32>   dst_ipv4;
}

header tcp_t {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<32>  seq_no;
    bit<32>  ack_no;
    bit<4>   data_offset;
    bit<4>   res;
    bit<8>   flags;
    bit<16>  window;
    bit<16>  checksum;
    bit<16>  urgent_ptr;
}

header udp_t {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<16>  hdr_length;
    bit<16>  checksum;
}

header icmp_t {
    bit<8>  type;
    bit<8>  code;
    bit<16>  checksum;
    bit<16>  identifier;
    bit<16>  sequence;
}

header probe_t {
    bit<8> data_cnt;
}

header probe_data_t {
    bit<8>    port_ingress;
    bit<8>    port_egress;
    bit<48>   current_time_ingress; // 入端口当前INT包进入时间
    bit<16>   packet_cnt_ingress;
    bit<16>   packet_cnt_egress;
    bit<16>   packet_len_ingress;
    bit<16>   packet_len_egress;
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/
struct my_ingress_headers_t {
    ethernet_t               ethernet;
    ipv4_t                   ipv4;
    arp_h                    arp;
    ipv6_t                   ipv6;
    tcp_t                    tcp;
    udp_t                    udp;
    icmp_t                   icmp;
    probe_t                  probe;
    probe_data_t[2]          probe_data;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct ingress_metadata_t {
    bit<8> trafficclass; // 00: other. 01: delay. 02: bandwidth. 03: reliabe.
    bit<16>  packet_cnt_add_ingress;
    bit<16>  packet_cnt_add_egress;
    bit<16>  packet_len_add_ingress;
    bit<16>  packet_len_add_egress;
    bit<32>  register_packet_cnt_idx;
    bit<32>  register_packet_cnt_idx_out;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/
parser MyParser(packet_in pkt,
                out my_ingress_headers_t hdr,
                inout ingress_metadata_t meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETH_TYPE_ARP: parse_arp;
            ETH_TYPE_IPV6: parse_ipv6;
            ETH_TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }
    state parse_ipv6{
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_hdr){
            IP_PROTO_TCP: parse_tcp;
            default: accept;
        }
    }
    state parse_ipv4{
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            IP_PROTO_TUNNEL: parse_tunnel;
            IP_PROTO_ICMP: parse_icmp;
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            IP_PROTO_INT: parse_int;
            default: accept;
        }
    }
    state parse_tunnel{
        pkt.extract(hdr.ipv6);
        transition parse_tcp;
    }
    state parse_icmp {
        pkt.extract(hdr.icmp);
        transition accept;
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition accept;
    }
    state parse_int {
        pkt.extract(hdr.probe);
        transition select(hdr.probe.data_cnt) {
            0: accept;
            1: parse_probe_list_1;
            2: parse_probe_list_2;
        }
    }
    state parse_probe_list_1 {
        pkt.extract(hdr.probe_data.next);
        transition accept;
    }

    state parse_probe_list_2 {
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        transition accept;
    }
}    
/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout my_ingress_headers_t hdr, inout ingress_metadata_t meta) {
    apply {  }
}    

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout my_ingress_headers_t hdr,
                  inout ingress_metadata_t meta,
                  inout standard_metadata_t standard_metadata){
    register<bit<16>>(35) register_packet_cnt;
    register<bit<16>>(35) register_packet_cnt_out;
    register<bit<16>>(35) register_packet_len;
    register<bit<16>>(35) register_packet_len_out;
    action drop() {
        mark_to_drop(standard_metadata);
    }
//********************************************************
    action ipv4_forward(bit<9> port) {
        standard_metadata.egress_spec = port;
    }
    table mapping_ipv4 {
        key = {
            hdr.ipv4.dst_ipv4: exact;
        }
        actions = {
            ipv4_forward;
            drop;
        }
        size = 1024;
        const default_action = drop();
    }
//******************************************************
    action get_traffic_class(bit<8> trafficclass) {
        meta.trafficclass = trafficclass; 
    }
    table trafficclass_set{
        key={
            hdr.ipv4.src_ipv4: exact;
            hdr.ipv4.dst_ipv4: exact;
            hdr.tcp.dst_port: exact;
        }
        actions={
            get_traffic_class();
        }
        default_action=get_traffic_class(0);
    }
//******************************************************
    action set_dscp(bit<8> dscp){
        hdr.ipv4.diffserv=dscp;
    }
    table dscp_get{
        key={
            hdr.ipv4.dst_ipv4: exact;
            meta.trafficclass: exact;
        }
        actions={
            set_dscp();
            drop();
        }
        default_action = drop();
    }
//******************************************************
    action set_register_index_ingress(bit<32> ingress_index){
        meta.register_packet_cnt_idx=ingress_index;
    }
    table register_index_get_ingress{
        key={
            standard_metadata.ingress_port: exact;
        }
        actions={
            set_register_index_ingress();
            drop();
        }
        default_action = drop();
    }
//******************************************************
    action set_register_index_egress(bit<32> egress_index){
        meta.register_packet_cnt_idx_out=egress_index;
    }
    table register_index_get_egress{
        key={
            standard_metadata.egress_spec: exact;
        }
        actions={
            set_register_index_egress();
            drop();
        }
        default_action = drop();
    }
    action route_to_server(bit<48> dst_mac,bit<9> port,bit<128> dst_ipv6){
        hdr.ethernet.src_mac=hdr.ethernet.dst_mac;
        hdr.ethernet.dst_mac=dst_mac;
        standard_metadata.egress_spec = port;
        hdr.ipv6.dst_ipv6=dst_ipv6;
        hdr.ipv4.setInvalid();
        hdr.ethernet.ether_type=ETH_TYPE_IPV6;
    }
    table service{
        key={
            hdr.ipv6.dst_ipv6:exact;
            hdr.tcp.dst_port:exact;
        }
        actions={
            route_to_server;
            drop;
        }
        default_action = drop();
    }
    action route_to_tunnel(bit<48> dst_mac,bit<9> port,bit<128> src_ipv6){
        hdr.ethernet.src_mac=hdr.ethernet.dst_mac;
        hdr.ethernet.dst_mac=dst_mac;
        standard_metadata.egress_spec = port;
        hdr.ipv6.src_ipv6=src_ipv6;
        hdr.ipv4.setValid();
        //TODO:添加相关ipv4隧道报文信息
        hdr.ethernet.ether_type=ETH_TYPE_IPV4;
        hdr.ipv4.src_ipv4=0x0A000002;
        hdr.ipv4.dst_ipv4=0x0A000001;
        hdr.ipv4.protocol=IP_PROTO_TUNNEL;
    }
    table service_reture{
        key={
            hdr.ipv6.dst_ipv6:exact;
            hdr.tcp.dst_port:exact;
        }
        actions={
            route_to_tunnel;
            drop;
        }
        default_action = drop();
    }
    apply{
        if (hdr.arp.isValid()) {
            //deal with arp packet
            if (hdr.arp.target_ip == 0xac1d5971) {
                // 172.29.89.113
                standard_metadata.egress_port = 24;
            }
            else if (hdr.arp.target_ip == 0xac1d5972) {
                // 172.29.89.114
                standard_metadata.egress_port = 56;
            }
            else if (hdr.arp.target_ip == 0xac1d597e) {
                // 172.29.89.126
                standard_metadata.egress_port = 64;
            }
            else {

            }
            meta.packet_cnt_add_ingress = 0;
            meta.packet_len_add_ingress = 0;
            meta.packet_cnt_add_egress = 0;
            meta.packet_len_add_egress = 0;
        }
        else if (hdr.ipv6.isValid()) {
            if(!hdr.ipv4.isValid()){
                service_reture.apply();
            }else{
                service.apply();
            }
        }
        else if (hdr.ipv4.isValid()) {
            //deal with ipv4 packet
            mapping_ipv4.apply();
            if(hdr.tcp.isValid()){
                trafficclass_set.apply();
                dscp_get.apply();
                meta.packet_cnt_add_ingress=1;
                meta.packet_len_add_ingress=14+hdr.ipv4.total_len;
                meta.packet_cnt_add_egress=1;
                meta.packet_len_add_egress=14+hdr.ipv4.total_len;
            }
            else if(hdr.udp.isValid()){
                hdr.ipv4.diffserv=0;
                meta.packet_cnt_add_ingress=1;
                meta.packet_len_add_ingress=14+hdr.ipv4.total_len;
                meta.packet_cnt_add_egress=1;
                meta.packet_len_add_egress=14+hdr.ipv4.total_len;
            }
             else if(hdr.icmp.isValid()){
                hdr.ipv4.diffserv=0;
            }
            else if(hdr.probe.isValid()){
                if (hdr.probe.data_cnt == 0) {
                    hdr.probe.data_cnt = hdr.probe.data_cnt + 1;
                    hdr.probe_data[0].setValid();
                    hdr.probe_data[0].port_ingress = (bit<8>)standard_metadata.ingress_port;
                    hdr.probe_data[0].port_egress = (bit<8>)standard_metadata.egress_spec;
                    // hdr.probe_data[0].current_time_ingress = ig_intr_prsr_md.global_tstamp;
                    hdr.probe_data[0].current_time_ingress = standard_metadata.ingress_global_timestamp;
                }
                else if (hdr.probe.data_cnt == 1) {
                    hdr.probe.data_cnt = hdr.probe.data_cnt + 1;
                    hdr.probe_data[1].setValid();
                    hdr.probe_data[1].port_ingress = (bit<8>)standard_metadata.ingress_port;
                    hdr.probe_data[1].port_egress = (bit<8>)standard_metadata.egress_spec;
                    // hdr.probe_data[1].current_time_ingress = ig_intr_prsr_md.global_tstamp;
                    hdr.probe_data[1].current_time_ingress = standard_metadata.ingress_global_timestamp;
                }
                meta.packet_cnt_add_ingress = 0;
                meta.packet_len_add_ingress = 0;
                meta.packet_cnt_add_egress = 0;
                meta.packet_len_add_egress = 0;
            }
        register_index_get_ingress.apply();
        register_index_get_egress.apply();
        bit<16> packet_cnt;
        register_packet_cnt.read(packet_cnt,meta.register_packet_cnt_idx);
        bit<16> new_packet_cnt=packet_cnt+meta.packet_cnt_add_ingress;
        register_packet_cnt.write(meta.register_packet_cnt_idx,new_packet_cnt);

        bit<16> packet_len;
        register_packet_len.read(packet_len,meta.register_packet_cnt_idx);
        bit<16> new_packet_len=packet_len+meta.packet_len_add_ingress;
        register_packet_len.write(meta.register_packet_cnt_idx,new_packet_len);

        bit<16> packet_cnt_out;
        register_packet_cnt_out.read(packet_cnt_out,meta.register_packet_cnt_idx_out);
        bit<16> new_packet_cnt_out=packet_cnt_out+meta.packet_cnt_add_egress;
        register_packet_cnt_out.write(meta.register_packet_cnt_idx_out,new_packet_cnt_out);

        bit<16> packet_len_out;
        register_packet_len_out.read(packet_len_out,meta.register_packet_cnt_idx_out);
        bit<16> new_packet_len_out=packet_len_out+meta.packet_len_add_egress;
        register_packet_len_out.write(meta.register_packet_cnt_idx_out,new_packet_len_out);

        // bit<16> packet_cnt = register_packet_cnt_add_action.execute(meta.register_packet_cnt_idx);
        // bit<16> packet_len = register_packet_len_add_action.execute(meta.register_packet_cnt_idx);
        // bit<16> packet_cnt_out = register_packet_cnt_add_action_out.execute(meta.register_packet_cnt_idx_out);
        // bit<16> packet_len_out = register_packet_len_add_action_out.execute(meta.register_packet_cnt_idx_out);

        if (hdr.probe.data_cnt == 1) {
            hdr.probe_data[0].packet_cnt_ingress = packet_cnt;
            hdr.probe_data[0].packet_len_ingress = packet_len;
            hdr.probe_data[0].packet_cnt_egress = packet_cnt_out;
            hdr.probe_data[0].packet_len_egress = packet_len_out;
            hdr.ipv4.total_len=hdr.ipv4.total_len+16;
        }
        else if (hdr.probe.data_cnt == 2) {
            hdr.probe_data[1].packet_cnt_ingress = packet_cnt;
            hdr.probe_data[1].packet_len_ingress = packet_len;
            hdr.probe_data[1].packet_cnt_egress = packet_cnt_out;
            hdr.probe_data[1].packet_len_egress = packet_len_out;
            hdr.ipv4.total_len=hdr.ipv4.total_len+16;
        }

        // bit<32> packet_cnt;
        // bit<32> new_packet_cnt;
        // bit<32> byte_cnt;
        // bit<32> new_byte_cnt;
        // bit<48> last_time;
        // bit<48> cur_time = standard_metadata.ingress_global_timestamp;
        // byte_cnt_reg.read(byte_cnt, (bit<32>)standard_metadata.ingress_port);
        // byte_cnt = byte_cnt + standard_metadata.packet_length;
        // new_byte_cnt = (hdr.probe_header.isValid()) ? 0 : byte_cnt;
        // byte_cnt_reg.write((bit<32>)standard_metadata.ingress_port, new_byte_cnt);
        // packet_cnt_reg.read(packet_cnt, (bit<32>)standard_metadata.ingress_port);
        // packet_cnt = packet_cnt + 1;
        // new_packet_cnt = (hdr.probe_header.isValid()) ? 0 : packet_cnt;
        // packet_cnt_reg.write((bit<32>)standard_metadata.ingress_port, new_packet_cnt);
        // if(hdr.ipv4.isValid()){
        //     ipv4_lpm.apply();
        // }
        // else if(hdr.ipv6.isValid()){
        //     hdr.probe_data.push_front(1);
        //     hdr.probe_data[0].setValid();    //说明这就是一个INT包
        //     hdr.probe_header.num_probe_data=hdr.probe_header.num_probe_data+1;
        //     swid.apply();
        //     hdr.probe_data[0].ingress_port = (bit<8>)standard_metadata.ingress_port;
        //     hdr.probe_data[0].ingress_byte_cnt = byte_cnt-standard_metadata.packet_length;
        //     last_time_reg.read(last_time, (bit<32>)standard_metadata.ingress_port);
        //     last_time_reg.write((bit<32>)standard_metadata.ingress_port, cur_time);
        //     hdr.probe_data[0].ingress_last_time = last_time;
        //     hdr.probe_data[0].ingress_cur_time = cur_time;
        //     hdr.probe_data[0].ingress_packet_count = packet_cnt-1;
        //     srv6_forward_table.apply();
        //     ipv6_lpm.apply();
        // }
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout my_ingress_headers_t hdr,
                 inout ingress_metadata_t meta,
                 inout standard_metadata_t standard_metadata) {
        apply{
            
        }
}
/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout my_ingress_headers_t  hdr, inout ingress_metadata_t meta) {
    apply {
        update_checksum(
        hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.total_len,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.frag_offset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.src_ipv4,
              hdr.ipv4.dst_ipv4 },
            hdr.ipv4.hdr_checksum,
            HashAlgorithm.csum16);
        }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/
control MyDeparser(packet_out pkt, in my_ingress_headers_t hdr) {
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.arp);
        pkt.emit(hdr.ipv6);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.icmp);
        pkt.emit(hdr.probe);
        pkt.emit(hdr.probe_data);
    }
}
/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
