#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
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
    bit<16>  payload_len; 
    bit<8>   next_hdr;
    bit<8>   hop_limit;
    bit<128> src_ipv6;
    bit<128> dst_ipv6;
}
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
    bit<8> data_index;
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
    ethernet_t          ethernet;
    arp_h               arp;
    ipv4_t              ipv4;
    ipv6_t              ipv6;
    tcp_t               tcp;
    udp_t               udp;
    icmp_t              icmp;
    probe_t             probe;
    probe_data_t[2]     probe_data;
}
    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/
struct ingress_metadata_t {
    bit<8>   trafficclass; // 00: default. 01: video. 02: gps. 03:route. 10: calculation.
    bit<16>  packet_cnt_add_ingress;
    bit<16>  packet_cnt_add_egress;
    bit<16>  packet_len_add_ingress;
    bit<16>  packet_len_add_egress;
    bit<32>  register_packet_cnt_idx;
    bit<32>  register_packet_cnt_idx_out;
}
 /***********************  P A R S E R  **************************/
parser IngressParser(packet_in pkt,
        /* User */    
        out my_ingress_headers_t hdr,
        out ingress_metadata_t meta,
        /* Intrinsic */
        out ingress_intrinsic_metadata_t ig_intr_md){
    state start {
        meta = {0,0,0,0,0,0,0};
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETH_TYPE_ARP: parse_arp;
            ETH_TYPE_IPV4: parse_ipv4;
            ETH_TYPE_IPV6: parse_ipv6;
            default: accept;
        }
    }
    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }
    state parse_ipv4{
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            IP_PROTO_TUNNEL: parse_ipv6;
            IP_PROTO_ICMP: parse_icmp;
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            IP_PROTO_INT: parse_int;
            default: accept;
        }
    }
    state parse_ipv6{
        pkt.extract(hdr.ipv6);
        transition accept;
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
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        transition accept;
    }
}
/***************** M A T C H - A C T I O N  *********************/
control Ingress( 
    /* User */
    inout my_ingress_headers_t hdr,
    inout ingress_metadata_t meta,
    /* Intrinsic */
    in ingress_intrinsic_metadata_t ig_intr_md,
    in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md){
//*************************************************************
    Register<bit<16>, bit<32>>(32w35, 0) register_packet_cnt;
    RegisterAction<bit<16>, bit<32>, bit<16>>(register_packet_cnt) register_packet_cnt_add_action = {
        void apply(inout bit<16> value, out bit<16> out_value) {
            value = value + meta.packet_cnt_add_ingress;
            out_value = value;
        }
    };

    Register<bit<16>, bit<32>>(32w35, 0) register_packet_cnt_out;
    RegisterAction<bit<16>, bit<32>, bit<16>>(register_packet_cnt_out) register_packet_cnt_add_action_out = {
        void apply(inout bit<16> value, out bit<16> out_value) {
            value = value + meta.packet_cnt_add_egress;
            out_value = value;
        }
    };

    Register<bit<16>, bit<32>>(32w35, 0) register_packet_len;
    RegisterAction<bit<16>, bit<32>, bit<16>>(register_packet_len) register_packet_len_add_action = {
        void apply(inout bit<16> value, out bit<16> out_value) {
            value = value + meta.packet_len_add_ingress;
            out_value = value;
        }
    };

    Register<bit<16>, bit<32>>(32w35, 0) register_packet_len_out;
    RegisterAction<bit<16>, bit<32>, bit<16>>(register_packet_len_out) register_packet_len_add_action_out = {
        void apply(inout bit<16> value, out bit<16> out_value) {
            value = value + meta.packet_len_add_egress;
            out_value = value;
        }
    };
//*************************************************************
    action drop() {
        ig_intr_dprsr_md.drop_ctl = 1;
    }
//*************************************************************
    action ipv6_forward(PortId_t port) {
        ig_intr_tm_md.ucast_egress_port = port;
    }
    action ipv6_to_ipv4tunnel(PortId_t port, bit<8> dscp, bit<32> src_ipv4, bit<32> dst_ipv4) {
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.ether_type = ETH_TYPE_IPV4;
        hdr.ipv4.setValid();
        hdr.ipv4.version = 4;
        hdr.ipv4.ihl = 5;
        hdr.ipv4.diffserv = dscp;
        hdr.ipv4.total_len = 60;
        hdr.ipv4.identification = 0;
        hdr.ipv4.flags = 0;
        hdr.ipv4.frag_offset = 0;
        hdr.ipv4.ttl = 64;
        hdr.ipv4.protocol = IP_PROTO_TUNNEL;
        hdr.ipv4.hdr_checksum = 0; 
        hdr.ipv4.src_ipv4 = src_ipv4;
        hdr.ipv4.dst_ipv4 = dst_ipv4;
    }
    action ipv4tunnel_to_ipv6(PortId_t port) {
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.ether_type = ETH_TYPE_IPV6;
        hdr.ipv4.setInvalid();
    }
    action change_addr(PortId_t port, bit<128> src_ipv66, bit<128> dst_ipv66, bit<48> src_mac, bit<48> dst_mac) {
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ipv6.src_ipv6 = src_ipv66;
        hdr.ipv6.dst_ipv6 = dst_ipv66;
        hdr.ethernet.src_mac = src_mac;
        hdr.ethernet.dst_mac = dst_mac;
    }
    table mapping_ipv6 {
        key = {
            hdr.ipv6.src_ipv6: exact;
            hdr.ipv6.dst_ipv6: exact;
        }
        actions = {
            ipv6_forward;
            ipv6_to_ipv4tunnel;
            ipv4tunnel_to_ipv6;
            change_addr;
            drop;
        }
        size = 1024;
        default_action = drop();
    }
//********************************************************
    // action change_mac(bit<48> dst_mac) {
    //     hdr.ethernet.dst_mac = dst_mac;
    // }
    // table change_mac_t {
    //     key = {
    //         hdr.ipv6.src_ipv6: exact;
    //         hdr.ipv6.dst_ipv6: exact;
    //     }
    //     actions = {
    //         change_mac;
    //         NoAction;
    //     }
    //     size = 1024;
    //     default_action = NoAction();
    // }
//********************************************************
    action ipv4_forward(PortId_t port) {
        ig_intr_tm_md.ucast_egress_port = port;
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
        default_action = drop();
    }
//******************************************************
    action get_traffic_class_dst(bit<8> trafficclass) {
        meta.trafficclass = trafficclass; 
    }
    table trafficclass_set_dst{
        key={
            hdr.ipv4.src_ipv4: exact;
            hdr.ipv4.dst_ipv4: exact;
            hdr.tcp.dst_port: exact;
        }
        actions={
            get_traffic_class_dst();
            NoAction();
        }
        default_action=NoAction();
    }
    action get_traffic_class_src(bit<8> trafficclass) {
        meta.trafficclass = trafficclass; 
    }
    table trafficclass_set_src{
        key={
            hdr.ipv4.src_ipv4: exact;
            hdr.ipv4.dst_ipv4: exact;
            hdr.tcp.src_port: exact;
        }
        actions={
            get_traffic_class_src();
            NoAction();
        }
        default_action=NoAction();
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
            NoAction();
        }
        default_action = NoAction();
    }
//******************************************************
    action set_register_index_ingress(bit<32> ingress_index){
        meta.register_packet_cnt_idx=ingress_index;
    }
    table register_index_get_ingress{
        key={
            ig_intr_md.ingress_port: exact;
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
            ig_intr_tm_md.ucast_egress_port: exact;
        }
        actions={
            set_register_index_egress();
            drop();
        }
        default_action = drop();
    }
//******************************************************
    apply{
        if (hdr.arp.isValid()) {
            //deal with arp packet
            if (hdr.arp.target_ip == 0xac1d597e) {
                // 172.29.89.126 gateway
                ig_intr_tm_md.ucast_egress_port = 64;
            }
            else if (hdr.arp.target_ip == 0xac1d5971) {
                // 172.29.89.113 host
                ig_intr_tm_md.ucast_egress_port = 24;
            }
            else if (hdr.arp.target_ip == 0xac1d5972) {
                // 172.29.89.114 host
                ig_intr_tm_md.ucast_egress_port = 56;
            }
            else if(hdr.arp.target_ip == 0xac1d5973){
                // 172.29.89.115 host
                ig_intr_tm_md.ucast_egress_port = 132;
            }
            else if(hdr.arp.target_ip == 0xac1d5974){
                // 172.29.89.116 host
                ig_intr_tm_md.ucast_egress_port = 65;
            }
            else {
                // other
            }
            meta.packet_cnt_add_ingress = 0;
            meta.packet_len_add_ingress = 0;
            meta.packet_cnt_add_egress = 0;
            meta.packet_len_add_egress = 0;
        }
        else if (hdr.ipv6.isValid()) {
            //deal with ipv6 packet
            mapping_ipv6.apply();
            // change_mac_t.apply();
        }
        else if (hdr.ipv4.isValid()) {
            //deal with ipv4 packet
            mapping_ipv4.apply();
            if(hdr.tcp.isValid()){
                hdr.ipv4.diffserv=0;
                meta.trafficclass=0;
                trafficclass_set_dst.apply();
                trafficclass_set_src.apply();
                dscp_get.apply();
                meta.packet_cnt_add_ingress=1;
                meta.packet_len_add_ingress=14+hdr.ipv4.total_len;
                meta.packet_cnt_add_egress=1;
                meta.packet_len_add_egress=14+hdr.ipv4.total_len;
            }
            else if(hdr.udp.isValid()){
                hdr.ipv4.diffserv=128;
                meta.packet_cnt_add_ingress=1;
                meta.packet_len_add_ingress=14+hdr.ipv4.total_len;
                meta.packet_cnt_add_egress=1;
                meta.packet_len_add_egress=14+hdr.ipv4.total_len;
            }
            else if(hdr.icmp.isValid()){
                hdr.ipv4.diffserv=0;
                meta.packet_cnt_add_ingress = 0;
                meta.packet_len_add_ingress = 0;
                meta.packet_cnt_add_egress = 0;
                meta.packet_len_add_egress = 0;
            }
            else if(hdr.probe.isValid()){
                if (hdr.probe.data_index == 0) {
                    hdr.probe_data[0].port_ingress = (bit<8>)ig_intr_md.ingress_port;
                    hdr.probe_data[0].port_egress = (bit<8>)ig_intr_tm_md.ucast_egress_port;
                    hdr.probe_data[0].current_time_ingress = ig_intr_prsr_md.global_tstamp;
                    //hdr.probe_data[0].current_time_ingress = ig_intr_md.ingress_mac_tstamp;
                }
                else if (hdr.probe.data_index == 1) {
                    hdr.probe_data[1].port_ingress = (bit<8>)ig_intr_md.ingress_port;
                    hdr.probe_data[1].port_egress = (bit<8>)ig_intr_tm_md.ucast_egress_port;
                    hdr.probe_data[1].current_time_ingress = ig_intr_prsr_md.global_tstamp;
                    //hdr.probe_data[1].current_time_ingress = ig_intr_md.ingress_mac_tstamp;
                }
                meta.packet_cnt_add_ingress = 0;
                meta.packet_len_add_ingress = 0;
                meta.packet_cnt_add_egress = 0;
                meta.packet_len_add_egress = 0;
            }
        }
        register_index_get_ingress.apply();
        register_index_get_egress.apply();
        // bit<32> register_packet_cnt_idx = (bit<32>) ig_intr_md.ingress_port;
        // bit<32> register_packet_cnt_idx_out = (bit<32>)ig_intr_tm_md.ucast_egress_port;
        bit<16> packet_cnt = register_packet_cnt_add_action.execute(meta.register_packet_cnt_idx);
        bit<16> packet_len = register_packet_len_add_action.execute(meta.register_packet_cnt_idx);
        bit<16> packet_cnt_out = register_packet_cnt_add_action_out.execute(meta.register_packet_cnt_idx_out);
        bit<16> packet_len_out = register_packet_len_add_action_out.execute(meta.register_packet_cnt_idx_out);
        if(hdr.probe.isValid()){
            if (hdr.probe.data_index == 0) {
                hdr.probe_data[0].packet_cnt_ingress = packet_cnt;
                hdr.probe_data[0].packet_len_ingress = packet_len;
                hdr.probe_data[0].packet_cnt_egress = packet_cnt_out;
                hdr.probe_data[0].packet_len_egress = packet_len_out;
            }
            else if (hdr.probe.data_index == 1) {
                hdr.probe_data[1].packet_cnt_ingress = packet_cnt;
                hdr.probe_data[1].packet_len_ingress = packet_len;
                hdr.probe_data[1].packet_cnt_egress = packet_cnt_out;
                hdr.probe_data[1].packet_len_egress = packet_len_out;
            }
            hdr.probe.data_index = hdr.probe.data_index + 1;
        }
    }
}

control IngressDeparser(packet_out pkt,
        /* User */
        inout my_ingress_headers_t hdr,
        in ingress_metadata_t meta,
        /* Intrinsic */
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md)
{
    Checksum() ipv4_checksum;
    apply {
        if (hdr.ipv4.isValid()){
            hdr.ipv4.hdr_checksum = ipv4_checksum.update(
            {
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_ipv4,
                hdr.ipv4.dst_ipv4
            }
            );
        }
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.arp);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.ipv6);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.icmp);
        pkt.emit(hdr.probe);
        pkt.emit(hdr.probe_data);
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_egress_headers_t {
    
}

    /********  G L O B A L   E G R E S S   M E T A D A T A  *********/

struct egress_metadata_t {
    
}

    /***********************  P A R S E R  **************************/

parser EgressParser(packet_in pkt,
     /* User */
     out my_egress_headers_t hdr,
     out egress_metadata_t meta,
     /* Intrinsic */
     out egress_intrinsic_metadata_t eg_intr_md)
{
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

control Egress(
         /* User */
         inout my_egress_headers_t hdr,
         inout egress_metadata_t meta,
         /* Intrinsic */    
         in egress_intrinsic_metadata_t eg_intr_md,
         in egress_intrinsic_metadata_from_parser_t eg_intr_prsr_md,
         inout egress_intrinsic_metadata_for_deparser_t eg_intr_dprsr_md,
         inout egress_intrinsic_metadata_for_output_port_t eg_intr_tm_md)
{
    apply{
    }
}

    /*********************  D E P A R S E R  ************************/

control EgressDeparser(packet_out pkt,
    /* User */
    inout my_egress_headers_t hdr,
    in egress_metadata_t meta,
    /* Intrinsic */
    in egress_intrinsic_metadata_for_deparser_t eg_intr_dprsr_md)
{
    apply {
        pkt.emit(hdr);
    }
}

/************ F I N A L   P A C K A G E ******************************/
Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;
