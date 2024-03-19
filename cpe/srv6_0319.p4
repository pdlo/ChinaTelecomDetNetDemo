#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
#define MAX_PORTS 8
#define MAX_HOPS 5

const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86dd;
const bit<16> TYPE_ARP = 0x0806;
//const bit<16> TYPE_PROBE = 0x0812;
const bit<8>  IP_PROTO_TCP = 8w6;
const bit<8>  IP_PROTO_UDP = 8w17;
const bit<8>  IP_PROTO_ICMP = 8w1;
const bit<48> VIRTUAL_MAC = 0x0a0a0a0a0a0a;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

//typedef bit<9>  egressSpec_t;
//typedef bit<48> macAddr_t;
//typedef bit<32> ip4Addr_t;

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16>   ether_type;
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

//INT头部
header probe_header_t {
    bit<8> num_probe_data;
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
    bit<32> src_addr;
    bit<32> dst_addr;
}

//--------------------------
//TCP首部
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
//--------------------------
//UDP首部
header udp_h {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<16>  hdr_length;
    bit<16>  checksum;
}
//--------------------------


/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/
struct my_ingress_headers_t {
    ethernet_t               ethernet;
    arp_h                    arp;
    //probe_header_t           probe_header;
    ipv6_h                   ipv6;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
    ipv4_t                   ipv4;
    tcp_h                    tcp;
    udp_h                    udp;
}



    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct ingress_metadata_t {
    bit<8>   segment_left;
    bit<128> segment_id; 
    bit<8>   flags;
    bit<32>  temp_ip;
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
        out ingress_intrinsic_metadata_t ig_intr_md)
{
     state start {
        //meta要初始化值，不然会警告
        meta = {2, 0, 0, 0, 0, 0, 0 ,0 ,0};
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            TYPE_ARP: parse_arp;
            TYPE_IPV4: parse_ipv4;
            TYPE_IPV6: parse_ipv6;
            //TYPE_PROBE: parse_probe;
            default: accept;
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            default: accept;
        }
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_hdr){
            43: parse_srv6;
            default: accept;
        }    
    }

    //srv6解析
    state parse_srv6 {
        pkt.extract(hdr.srv6h);  //这里需要有判断segment list个数的方法
        transition select(hdr.srv6h.segment_left){
            0: parse_ipv4;
            1: parse_srv6_list_1;
            2: parse_srv6_list_1;
            3: parse_srv6_list_1;
            4: parse_srv6_list_1;
            5: parse_srv6_list_1;
            default: reject;
        }
    }

    state parse_srv6_list_1 {
        pkt.extract(hdr.srv6_list.next); //提取segment list的栈的第一个元素
        transition select(hdr.srv6h.segment_left){
            1: parse_ipv4;
            default: parse_srv6_list_2;
        }
        }
    
    state parse_srv6_list_2 {
        pkt.extract(hdr.srv6_list.next); 
        transition select(hdr.srv6h.segment_left){
            2: parse_ipv4;
            default: parse_srv6_list_3;
        }
        }

    state parse_srv6_list_3 {
        pkt.extract(hdr.srv6_list.next); 
        transition select(hdr.srv6h.segment_left){
            3: parse_ipv4;
            default: parse_srv6_list_4;
        }
        }

    state parse_srv6_list_4 {
        pkt.extract(hdr.srv6_list.next); 
        transition select(hdr.srv6h.segment_left){
            4: parse_ipv4;
            default: parse_srv6_list_5;
        }
        }
    
    state parse_srv6_list_5 {
        pkt.extract(hdr.srv6_list.next); 
        transition parse_ipv4;
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


//---------------------------------------ipv6和srv6插入-----------------------------------------------

    action srv6_insert(bit<8> num_segments, 
        bit<48> src_mac, bit<48> dst_mac, bit<9> port, 
        bit<128> s1, bit<128> s2, bit<128> s3, bit<128> s4, bit<128> s5){
        
        //ipv4转发
        hdr.ethernet.srcAddr = src_mac;
        hdr.ethernet.dstAddr = dst_mac;
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.ether_type = TYPE_IPV6;

        hdr.ipv6.setValid();
        // 设置IPv6头部字段
        hdr.ipv6.version = 6;  // IPv6版本
        hdr.ipv6.traffic_class = 0;  // 通信等级
        hdr.ipv6.flow_label = 0;  // 流标签
        hdr.ipv6.payload_len = 10;  // 负载长度
        hdr.ipv6.next_hdr = 43;  // 扩展头协议，43为SRV6数据包，44为INT数据包
        hdr.ipv6.hop_limit = 6;  // 跳数限制
        hdr.ipv6.src_addr = 100;  // 源地址
        hdr.ipv6.dst_addr = 80;  // 目标地址

        //srv6 header插入，这个num_segements是总共的跳数
        hdr.srv6h.setValid();
        hdr.srv6h.next_hdr = 2;  
        //hdr.srv6h.hdr_ext_len =  (num_segments << 4) + 8;  
        hdr.srv6h.hdr_ext_len = 88;
        hdr.srv6h.routing_type = 4;
        hdr.srv6h.segment_left = num_segments;
        hdr.srv6h.last_entry = num_segments;
        hdr.srv6h.flags = 0;
        hdr.srv6h.tag = 0;


        hdr.ipv6.payload_len = hdr.ipv4.totalLen + 88;  //8+16*5=88

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
        //插入srv6头部
        key = {
           hdr.ipv4.dst_addr: lpm;       
        }
        actions = {
            srv6_insert();
            drop;
        }
        default_action = drop();   
    }

//---------------------------------------srv6丢弃-----------------------------------------------  

    action srv6_abandon_set(bit<48> src_mac, bit<48> dst_mac, bit<9> port) {
        //ipv4转发
        hdr.ethernet.srcAddr = src_mac;
        hdr.ethernet.dstAddr = dst_mac;
        ig_intr_tm_md.ucast_egress_port = port;

        hdr.ethernet.ether_type = TYPE_IPV6;


        hdr.ethernet.ether_type = TYPE_IPV4;

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
            hdr.ipv4.dst_addr: lpm;
        }
        actions = {
            srv6_abandon_set();
            drop();
        }
        default_action = drop();
    }
    
//------------------------------------------------------------------------------------------------------
    
//--------------------------------------------------------------------------------------------------------


    apply {
        if (hdr.arp.isValid()) {
            //arp欺骗
            //改成通用的
            hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
            hdr.ethernet.srcAddr = VIRTUAL_MAC;

            hdr.arp.OPER = 2;

            meta.temp_ip = hdr.arp.sender_ip;
            
            hdr.arp.sender_ip = hdr.arp.target_ip;
            hdr.arp.target_ip = meta.temp_ip;

            hdr.arp.target_ha = hdr.arp.sender_ha;
            hdr.arp.sender_ha = VIRTUAL_MAC;
            
            ig_intr_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        }

       
        if (hdr.srv6h.isValid()){
             //删除srv6头部
            if (hdr.srv6h.segment_left == 0) {
                srv6_abandon.apply();
            }
            else{
                drop();
            }
        }
        else {
            if (hdr.ipv4.isValid()){
            //五元组匹配来判断是否插入srv6，ipv6头部插入(目前是只通过目的ip地址来判断)
            //只要是ipv4包都插入srv6头部
            srv6_handle.apply();
            //这里可以优化，直接根据地址是否为0来存储
            /*
            if (meta.s1 != 0){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s1;
            } 

            if (meta.s2 != 0){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s2;
            } 

            if (meta.s3 != 0){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s3;
            } 

            if (meta.s4 != 0){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s4;
            } 

            if (meta.s5 != 0){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s5;
            } 
            */
                    
        }

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