
#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
#define MAX_HOPS 5

const bit<16> ETH_TYPE_IPV4 = 0x0800;
const bit<16> ETH_TYPE_IPV6 = 0x86dd;
const bit<16> ETH_TYPE_ARP = 0x0806;

const bit<8>  IPv6_NEXTHEADER_IPv4 = 4;
const bit<8>  IPv6_NEXTHEADER_SRV6 = 43;
const bit<8>  IPv6_NEXTHEADER_CAL = 150;
const bit<8>  IPv6_NEXTHEADER_INT = 200;

const bit<8>  IP_PROTO_ICMP = 1;
const bit<8>  IP_PROTO_TCP = 6;
const bit<8>  IP_PROTO_UDP = 17;

const bit<48> VIRTUAL_MAC = 0x0a0a0a0a0a0a;

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

header ipv6_h {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_len;  //记录载荷长（包括srh长度）
    bit<8>   next_hdr;  //IPV6基本报头后的那一个扩展包头的信息类型，SRH定为43
    bit<8>   hop_limit;
    bit<128> src_ipv6;
    bit<128> dst_ipv6;
}  //需要ipv6的某一个字段来判断扩展头是否为srv6扩展头


header srv6h_t {
    bit<8>  next_hdr;
    bit<8>  hdr_ext_len;  //扩展头长度
    bit<8>  routing_type;  //标识扩展包头类型，4表示为SRH
    bit<8>  segment_left;  //用这个字段来确定剩余跳数
    bit<8>  last_entry;   //最后一个seg list的索引
    bit<8>  flags;   
    bit<16> tag;
}

header srv6_list_t {
    bit<128> segment_id;  //ipv6地址
} 

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    bit<32>   src_ipv4;
    bit<32>   dst_ipv4;
}

header tcp_h {
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

header udp_h {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<16>  hdr_length;
    bit<16>  checksum;
}

header icmp_h {
    bit<8>  type;
    bit<8>  code;
    bit<16>  checksum;
    bit<16>  identifier;
    bit<16>  sequence;
}

header probe_h {
    bit<8> data_cnt;
}

header probe_data_h {
    bit<8>    swid; // 交换机标识
    bit<8>    port_ingress; // 入端口号
    bit<8>    port_egress; // 出端口号
    bit<32>   byte_ingress; // 入端口累计入流量
    bit<32>   byte_egress; // 出端口累计出流量
    bit<32>   count_ingress; // 入端口累计入个数
    bit<32>   count_egress; // 出端口累计出个数
    bit<48>   last_time_ingress; // 入端口上一个INT包进入时间
    bit<48>   last_time_egress; // 出端口上一个INT包离开时间
    bit<48>   current_time_ingress; // 入端口当前INT包进入时间
    bit<48>   current_time_egress; // 出端口当前INT包离开时间
    bit<32>   qdepth; // 队列长度
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/
struct my_ingress_headers_t {
    ethernet_t               ethernet;
    arp_h                    arp;
    ipv6_h                   ipv6;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
    ipv4_t                   ipv4;
    tcp_h                    tcp;
    udp_h                    udp;
    icmp_h                   icmp;
    probe_h                  probe;
    probe_data_h[MAX_HOPS]   probe_data;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct ingress_metadata_t {
    bit<8> trafficclass;
    bit<8> last_entry;
    bit<128> s1;
    bit<128> s2;
    bit<128> s3;
    bit<128> s4;
    bit<128> s5;
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
            ETH_TYPE_IPV6: parse_ipv6;
            ETH_TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_hdr){
            IPv6_NEXTHEADER_CAL: parse_cal;
            IPv6_NEXTHEADER_SRV6: parse_srv6;
            default: accept;
        }    
    }

    state parse_cal {
        transition accept;
    }

    //srv6解析
    state parse_srv6 {
        pkt.extract(hdr.srv6h); 
        transition select(hdr.srv6h.last_entry){
            0: parse_srv6_list_1;
            1: parse_srv6_list_2;
            2: parse_srv6_list_3;
            3: parse_srv6_list_4;
            4: parse_srv6_list_5;
            default: accept;
        }
    }

    state parse_srv6_list_1 {
        pkt.extract(hdr.srv6_list.next);
        transition select(hdr.srv6h.next_hdr){
            IPv6_NEXTHEADER_INT: parse_probe;
            IPv6_NEXTHEADER_IPv4: parse_ipv4;
            default: accept;
        }
    }
    
    state parse_srv6_list_2 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition select(hdr.srv6h.next_hdr){
            IPv6_NEXTHEADER_INT: parse_probe;
            IPv6_NEXTHEADER_IPv4: parse_ipv4;
            default: accept;
        }
    }

    state parse_srv6_list_3 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition select(hdr.srv6h.next_hdr){
            IPv6_NEXTHEADER_INT: parse_probe;
            IPv6_NEXTHEADER_IPv4: parse_ipv4;
            default: accept;
        }
    }

    state parse_srv6_list_4 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition select(hdr.srv6h.next_hdr){
            IPv6_NEXTHEADER_INT: parse_probe;
            IPv6_NEXTHEADER_IPv4: parse_ipv4;
            default: accept;
        }
    }
    
    state parse_srv6_list_5 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition select(hdr.srv6h.next_hdr){
            IPv6_NEXTHEADER_INT: parse_probe;
            IPv6_NEXTHEADER_IPv4: parse_ipv4;
            default: accept;
        }
    }

    state parse_probe {
        pkt.extract(hdr.probe);
        transition select(hdr.probe.data_cnt){
            0:accept;    
            1:parse_probe_list_1;
            2:parse_probe_list_2;
            3:parse_probe_list_3;
            4:parse_probe_list_4;
            5:parse_probe_list_5;
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

    state parse_probe_list_3 {
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        transition accept;
    }

    state parse_probe_list_4 {
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        transition accept;
    }

    state parse_probe_list_5 {
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        pkt.extract(hdr.probe_data.next);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTO_ICMP: parse_icmp;
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            default: accept;
        }
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
    inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md)
{
    action drop() {
        ig_intr_dprsr_md.drop_ctl = 1;
    }
//---------------------------------------ipv4转发-----------------------------------------------  
    action ipv4_forward(bit<48> src_mac, bit<48> dst_mac, bit<9> port) {
        // 出端口
        ig_intr_tm_md.ucast_egress_port = port;
        // MAC层
        hdr.ethernet.src_mac = src_mac;
        hdr.ethernet.dst_mac = dst_mac;
        hdr.ethernet.ether_type = ETH_TYPE_IPV4; 
    }
    table ipv4_lpm{
        key = {
            hdr.ipv4.dst_ipv4: exact;
        }
        actions = {
            ipv4_forward();
            drop();
        }
        default_action = drop();
    }
//----------------------------------------服务等级映射------------------------------------------------------
    action get_traffic_class(bit<8> trafficclass) {
        //根据流表下发的等级来判断,默认为0，如果有流表，则等级为1
        meta.trafficclass = trafficclass; 
    }
    table select_traffic_class{
        key = {
            hdr.ipv4.dst_ipv4: exact;
            hdr.ipv4.src_ipv4: exact;
            hdr.tcp.dst_port: exact;
        }
        actions = {
            get_traffic_class();
        }
        default_action = get_traffic_class(0);
    }
//---------------------------------------IPv6插入-----------------------------------------------
    action ipv6_insert(bit<128> src_ipv6, bit<128> dst_ipv6){
        // MAC 层
        hdr.ethernet.ether_type = ETH_TYPE_IPV6;

        // IPv6层
        hdr.ipv6.setValid();
        hdr.ipv6.version = 6;  // IPv6版本
        hdr.ipv6.traffic_class = 0;  // 通信等级
        hdr.ipv6.flow_label = 0;  // 流标签
        hdr.ipv6.payload_len = hdr.ipv4.totalLen + 88;  //8+16*5=88
        hdr.ipv6.next_hdr = 43;  // 扩展头协议，43为SRV6数据包
        hdr.ipv6.hop_limit = 6;  // 跳数限制
        hdr.ipv6.src_ipv6 = src_ipv6;  // 源地址
        hdr.ipv6.dst_ipv6 = dst_ipv6;  // 目标地址
    }
    table select_srv6_path_1 {      
        //获取srv6头部信息
        key = {
            hdr.ipv4.dst_ipv4: exact;   //目的ipv4
            meta.trafficclass: exact;   //流等级       
        }
        actions = {
            ipv6_insert();
            drop();
        }
        default_action = drop();   
    }
//---------------------------------------srv6插入-----------------------------------------------
    action srv6_insert(bit<8> num_segments, bit<8> last_entry, 
        bit<128> s1, bit<128> s2, bit<128> s3, bit<128> s4, bit<128> s5){
        // SRv6层
        hdr.srv6h.setValid();
        hdr.srv6h.next_hdr = 4;  //1为icmp,2为IGMP，6为TCP协议，17为UDP，4为ipv4，41为ipv6
        hdr.srv6h.hdr_ext_len = 88;
        hdr.srv6h.routing_type = 4;
        hdr.srv6h.segment_left = num_segments;
        hdr.srv6h.last_entry = last_entry;
        hdr.srv6h.flags = 0;
        hdr.srv6h.tag = 0;

        // 存储数据
        meta.last_entry = last_entry;
        meta.s1 = s1;
        meta.s2 = s2;
        meta.s3 = s3;
        meta.s4 = s4;
        meta.s5 = s5;
    }
    table select_srv6_path_2 {      
        //获取srv6头部信息
        key = {
            hdr.ipv4.dst_ipv4: exact;   //目的ipv4
            meta.trafficclass: exact;   //流等级       
        }
        actions = {
            srv6_insert();
            drop();
        }
        default_action = drop();   
    }
//---------------------------------------ipv6转发-----------------------------------------------  
    action ipv6_forward(bit<48> src_mac, bit<48> dst_mac, bit<9> port) {
        // 出端口
        ig_intr_tm_md.ucast_egress_port = port;
        // MAC层
        hdr.ethernet.src_mac = src_mac;
        hdr.ethernet.dst_mac = dst_mac;
        hdr.ethernet.ether_type = ETH_TYPE_IPV6; 
    }
    table ipv6_lpm{
        key = {
            hdr.ipv6.dst_ipv6: exact;
        }
        actions = {
            ipv6_forward();
            drop();
        }
        default_action = drop();
    }
//--------------------------------------------apply-------------------------------------------------------
    apply {
        if (hdr.arp.isValid()) {
            // for arp
            hdr.ethernet.dst_mac = hdr.ethernet.src_mac;
            hdr.ethernet.src_mac = VIRTUAL_MAC;
            hdr.arp.OPER = 2;
            bit<32> temp_ip = hdr.arp.sender_ip;
            hdr.arp.sender_ip = hdr.arp.target_ip;
            hdr.arp.target_ip = temp_ip;
            hdr.arp.target_ha = hdr.arp.sender_ha;
            hdr.arp.sender_ha = VIRTUAL_MAC;
            ig_intr_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        }
        else if (hdr.ipv6.isValid()) {
            // for ipv6
            if (hdr.srv6h.isValid()) {
                // for ipv6+srv6
                if (hdr.probe.isValid()) {
                    // for ipv6+srv6+int
                }
                else if (hdr.ipv4.isValid()) {
                    // for ipv6+srv6+ipv4
                    // 删除srv6头部
                    hdr.ipv6.setInvalid();
                    hdr.srv6h.setInvalid();
                    hdr.srv6_list[0].setInvalid();
                    hdr.srv6_list[1].setInvalid();
                    hdr.srv6_list[2].setInvalid();
                    hdr.srv6_list[3].setInvalid();
                    hdr.srv6_list[4].setInvalid();  
                    //ipv4转发 
                    ipv4_lpm.apply();
                }
            }
            else {
                // for ipv6+cal
            }
        }
        else if (hdr.ipv4.isValid()) {
            // for ipv4
            if (hdr.tcp.isValid()) {
                // for ipv4+tcp
                select_traffic_class.apply();
            }
            else if (hdr.udp.isValid()) {
                // for ipv4+udp
                meta.trafficclass = 0;
            }
            else if (hdr.icmp.isValid()) {
                // for ipv4+icmp
                meta.trafficclass = 0;
            }

            select_srv6_path_1.apply();
            select_srv6_path_2.apply();
            ipv6_lpm.apply();

            if (meta.last_entry == 0) {
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s1;
            }
            else if (meta.last_entry == 1) {
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s1;

                hdr.srv6_list[1].setValid();
                hdr.srv6_list[1].segment_id = meta.s2;
            }
            else if (meta.last_entry == 2) {
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s1;

                hdr.srv6_list[1].setValid();
                hdr.srv6_list[1].segment_id = meta.s2;

                hdr.srv6_list[2].setValid();
                hdr.srv6_list[2].segment_id = meta.s3;
            }
            else if (meta.last_entry == 3) {
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s1;

                hdr.srv6_list[1].setValid();
                hdr.srv6_list[1].segment_id = meta.s2;

                hdr.srv6_list[2].setValid();
                hdr.srv6_list[2].segment_id = meta.s3;

                hdr.srv6_list[3].setValid();
                hdr.srv6_list[3].segment_id = meta.s4;
            }
            else if (meta.last_entry == 4) {
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s1;

                hdr.srv6_list[1].setValid();
                hdr.srv6_list[1].segment_id = meta.s2;

                hdr.srv6_list[2].setValid();
                hdr.srv6_list[2].segment_id = meta.s3;

                hdr.srv6_list[3].setValid();
                hdr.srv6_list[3].segment_id = meta.s4;

                hdr.srv6_list[4].setValid();
                hdr.srv6_list[4].segment_id = meta.s5; 
            }
            else{
            }
        }
        else {
        }
    }
}

    /*********************  D E P A R S E R  ************************/

control IngressDeparser(packet_out pkt,
        /* User */
        inout my_ingress_headers_t hdr,
        in ingress_metadata_t meta,
        /* Intrinsic */
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md)
{
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.arp);
        pkt.emit(hdr.ipv6);
        pkt.emit(hdr.srv6h);
        pkt.emit(hdr.srv6_list);
        pkt.emit(hdr.ipv4);
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
    apply {
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