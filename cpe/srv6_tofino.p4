/* -*- P4_16 -*- */
#include <core.p4>
#include <tna.p4>

#define MAX_PORTS 8
#define MAX_HOPS 5

const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86dd;
const bit<16> TYPE_ARP = 0x0806;
const bit<16> TYPE_PROBE = 0x0812;
const bit<8>  IP_PROTO_TCP = 8w6;
const bit<8>  IP_PROTO_UDP = 8w17;
const bit<8>  IP_PROTO_ICMP = 8w1;
const bit<48> VIRTUAL_MAC = 1;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

//--------------------------
// ARP首部
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
    bit<128> src_addr;
    bit<128> dst_addr;
}  //需要ipv6的某一个字段来判断扩展头是否为srv6扩展头


header srv6h_t {
    bit<8> next_hdr;
    bit<8> hdr_ext_len;  //扩展头长度
    bit<8> routing_type;  //标识扩展包头类型，4表示为SRH
    bit<8> segment_left;  //用这个字段来确定剩余跳数
    bit<8> last_entry;   //最后一个seg list的索引
    bit<8> flags;   //目前用于解析循环，写死为5
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
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

struct headers {
    ethernet_t               ethernet;
    ipv6_h                   ipv6;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
    ipv4_t                   ipv4;
}

/******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct ingress_metadata_t {
    bit<8>   remaining1;
    bit<8>   remaining2;
    bit<8>   sswid;
    bit<32>  pktcont2;
    bit<9>   ingress_time;
    bit<8>   segment_left;
    bit<128> segment_id; 
    bit<8>   flags;
    bit<32> temp_ip;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                out ingress_metadata_t meta,
                out ingress_intrinsic_metadata_t ig_intr_md) {

    state start {
        meta.temp_ip=0;

        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            TYPE_IPV6: parse_ipv6;
            TYPE_ARP: parse_arp;
            default: accept;
        }
    }

    state parse_arp {
        packet.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }

    state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_hdr){
            43: parse_srv6;
            default: accept;
        }    
    }

    //srv6解析
    state parse_srv6 {
        packet.extract(hdr.srv6h);  //这里需要有判断segment list个数的方法
        //meta.last_entry = hdr.srv6h.last_entry; //判断segment list个数的方法
        meta.segment_left = hdr.srv6h.segment_left; //剩余跳数，用这个值来判断解析哪个SID
        meta.flags = hdr.srv6h.flags - 1;
        transition select(meta.segment_left){
            0: accept;
            default: parse_srv6_list;
        }  
    }

    state parse_srv6_list {
        packet.extract(hdr.srv6_list.next); //提取segment list的栈的第一个元素
        meta.flags = meta.flags - 1;
        transition select(meta.flags){
            0: parse_ipv4;
            default: parse_srv6_list;
        }                  
    }
    //数据包对应的数据都能获取到，需要获取segment_list的数量，这样才好解析。
    
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(
    /* User */
    inout headers hdr,
    inout ingress_metadata_t meta,
    /* Intrinsic */
    in ingress_intrinsic_metadata_t ig_intr_md,
    in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {
    
    action drop() {
        //mark_to_drop(standard_metadata);
        ig_intr_dprsr_md.drop_ctl = 1;
    }

//---------------------------------------IPV4转发-----------------------------------------------
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        //ipv6_h_insert();
        //srv6_t_insert_5();
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        
    }


    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
        }
        size = 1024;
        default_action = drop;  // default_action必须是在actions里选一个
    }
 

//---------------------------------------IPV6转发-----------------------------------------------
    action ipv6_forward(macAddr_t dstAddr, egressSpec_t port) {
        //ipv6_h_insert();
        //srv6_t_insert_5();
        ig_intr_md.ucast_egress_port = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        
    }


    table ipv6_lpm {
        key = {
            hdr.ipv6.dst_addr: lpm;
        }
        actions = {
            ipv6_forward;
            drop;
        }
        size = 1024;
        default_action = drop;  // default_action必须是在actions里选一个
    }


//---------------------------------------srv6插入-----------------------------------------------

    action srv6_insert(bit<8> num_segments, bit<128> s1, bit<128> s2, bit<128> s3, bit<128> s4, bit<128> s5){
        //srv6 header插入
        hdr.srv6h.setValid();
        hdr.srv6h.next_hdr = 2;  //待定
        hdr.srv6h.hdr_ext_len =  (num_segments << 4) + 8;  
        hdr.srv6h.routing_type = 4;
        hdr.srv6h.segment_left = num_segments;
        hdr.srv6h.last_entry = num_segments - 1;
        hdr.srv6h.flags = 0;
        hdr.srv6h.tag = 0;


        hdr.ipv6.payload_len = hdr.ipv6.payload_len + 88;  //8+16*5=88
        //insert_srv6h_header(5); 最多5跳，若少于5跳，后面的ipv6地址置0
        //hdr.srv6_list.push_front();
        //push_front(count)是将元素右移count位，然后前count位失效，后count位丢弃，不是压入栈。

        hdr.srv6_list[0].setValid();
        hdr.srv6_list[0].segment_id = s1;

        hdr.srv6_list[1].setValid();
        hdr.srv6_list[1].segment_id = s2;

        hdr.srv6_list[2].setValid();
        hdr.srv6_list[2].segment_id = s3;

        hdr.srv6_list[3].setValid();
        hdr.srv6_list[3].segment_id = s4;

        hdr.srv6_list[4].setValid();
        hdr.srv6_list[4].segment_id = s5;

        
    }
    table srv6_handle {      
        //插入和丢弃srv6头部
        key = {
           hdr.ethernet.etherType: exact;       
        }
        actions = {
            srv6_insert;
            drop;
        }
        default_action = drop();   
    }

//---------------------------------------srv6丢弃-----------------------------------------------  

    action srv6_abandon_set() {
        hdr.ethernet.etherType = TYPE_IPV4;

        hdr.ipv6.setInvalid();

        hdr.srv6h.setInvalid();
        hdr.srv6_list[0].setInvalid();
        hdr.srv6_list[1].setInvalid();
        hdr.srv6_list[2].setInvalid();
        hdr.srv6_list[3].setInvalid();
        hdr.srv6_list[4].setInvalid();   
    }

    table srv6_abandon{
        key = {
            hdr.ipv6.next_hdr: exact;
        }
        actions = {
            srv6_abandon_set;
            drop;
        }
        default_action = drop();
    }


//-------------------------------------------------------------------------------------------------
    apply {
        if (hdr.arp.isValid()) {
            
            hdr.ethernet.dst_mac = hdr.ethernet.src_mac;
            hdr.ethernet.src_mac = VIRTUAL_MAC;

            hdr.arp.OPER = 2;

            meta.temp_ip = hdr.arp.sender_ip;
            
            hdr.arp.sender_ip = hdr.arp.target_ip;

            hdr.arp.target_ip = meta.temp_ip;
            hdr.arp.target_ha = hdr.arp.sender_ha;

            hdr.arp.sender_ha = VIRTUAL_MAC;
            
            ig_intr_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        }
        else{
            if(hdr.srv6.isValid()){
                srv6_abandon.apply();
            }
            else{
                srv6_handle.apply();
            }
            ipv6_lpm.apply();
        }
    }
    
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, 
        /* User */
        inout my_ingress_headers_t hdr,
        in ingress_metadata_t meta,
        /* Intrinsic */
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) 
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.srv6h);
        packet.emit(hdr.srv6_list);
        packet.emit(hdr.ipv4);
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

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

Pipeline(
    MyParser(),
    MyIngress(),
    MyDeparser(),
    EgressParser();
    Egress();
    EgressDeparser();
) pipe;

Switch(pipe) main;
