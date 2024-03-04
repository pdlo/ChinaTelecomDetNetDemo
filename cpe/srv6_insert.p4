/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define MAX_PORTS 255
#define MAX_HOPS 5

const bit<16> ETH_TYPE_IPV4 = 0x0800;
const bit<16> ETH_TYPE_IPV6 = 0x86dd;

register< bit<32> >(16) register_ingress_packet_count;
register< bit<32> >(16) register_egress_packet_count;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/
header ethernet_h {
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

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

// IPv4首部
header ipv4_h {
    bit<4>   version;
    bit<4>   ihl;
    bit<8>   diffserv;
    bit<16>  total_len;
    bit<16>  identification;
    bit<3>   flags;
    bit<13>  frag_offset;
    bit<8>   ttl;
    bit<8>   protocol;
    bit<16>  hdr_checksum;
    bit<32>  src_addr;
    bit<32>  dst_addr;
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

//INT首部
header probe_h {
    bit<8>    hop_cnt; // probe_fwd字段个数
    bit<8>    data_cnt; // probe_data字段个数
}
//--------------------------
header probe_fwd_h {
    bit<8>   swid; // 交换机标识
}
//--------------------------
header probe_data_h {
    bit<8>    swid; // 交换机标识
    bit<8>    port; // 端口号
    bit<32>   byte_cnt; // 流量
    bit<32>   pckcont; // 入口数据包个数
    bit<32>   enpckcont; // 出口数据包个数
    bit<48>   last_time; // 上一个INT包到达时间
    bit<48>   cur_time; // 当前INT包到达时间
    bit<32>   qdepth; // 队列长度
}
//--------------------------
// ICMP首部
header icmp_h {
    bit<8>   type;
    bit<8>   code;
    bit<16>  hdr_checksum;
}
//--------------------------
//SINET首部
header sinet_h {
    bit<4>   version;
    bit<8>   slice_id;
    bit<20>  flow_label;
    bit<16>  payload_len;
    bit<8>   src_id_len;
    bit<8>   dst_id_len;
    bit<32>  src_id;
    bit<32>  dst_id;
    bit<16>  protocol_id;
    bit<8>   hop_limit;
}
//--------------------------

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
struct metadata {
    bit<8>   remaining1;
    bit<8>   remaining2;
    bit<8>   sswid;
    bit<32>  pktcont2;
    bit<9>   ingress_time;
}

header srv6h_t {
    bit<8> next_hdr;
    bit<8> hdr_ext_len;  //扩展头长度
    bit<8> routing_type;  //标识扩展包头类型，4表示为SRH
    bit<8> segment_left;  //用这个字段来确定解析时的segment list数量
    bit<8> last_entry;   //最后一个seg list的索引
    bit<8> flags;
    bit<16> tag;
}

header srv6_list_t {
    bit<128> segment_id;  //ipv6地址
} 


struct headers {
    ethernet_h               ethernet;
    arp_h                    arp;
    ipv4_h                   ipv4;
    probe_h                  probe;
    probe_fwd_h[MAX_HOPS]    probe_fwd;
    probe_data_h[MAX_HOPS]   probe_data;
    ipv6_h                   ipv6;
    icmp_h                   icmp;
    sinet_h                  sinet;
    tcp_h                    tcp;
    udp_h                    udp;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
}
/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/
parser MyParser(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            TYPE_PROBE: parse_probe;
            TYPE_IPV6: parse_ipv6;
            TYPE_SINET: parse_sinet;
            TYPE_ARP: parse_arp;
            default: accept;
        }
    }

//--------------------------------------------------
state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_hdr){
            43: parse_srv6;
            default: accept;
        }
        
    }


//--------------------------------------------------
//模板   
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            IP_PROTO_ICMP: parse_icmp;
            default: accept;
    }

    state parse_tcp {
       packet.extract(hdr.tcp);
       transition accept;
    }

    state parse_udp {
       packet.extract(hdr.udp);
       transition accept;
    }

    state parse_icmp {
        packet.extract(hdr.icmp);
        transition accept;
    }

//--------------------------------------------------
//srv6解析
    state parse_srv6 {
        packet.extract(hdr.srv6h);  //这里需要有判断segment list个数的方法
        meta.last_entry = hdr.srv6h.last_entry; //判断segment list个数的方法
        meta.segment_left = hdr.srv6h.segment_left; //剩余跳数，用这个值来判断解析哪个SID
        transition select(meta.segment_left){
            0: accept;
            default: parse_srv6_list;
        }  
    }

    state parse_srv6_list {
        packet.extract(srv6_list.segment_id.next); //提取segment list的栈的第一个元素
        meta.segment_left = meta.segment_left - 1;  //segment_left的值为list的最大索引值减一（这里list一定要及时弹出，不然地址使用会重复）
        transition select(meta.segment_left){
            0: accept;
            default: parse_srv6_list;
        }
    }

    //数据包对应的数据都能获取到，需要获取segment_list的数量，这样才好解析。
    
}
/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/
control c_verify_checksum(inout headers hdr, inout metadata meta) {
    apply {}
}
/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/
control Myingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action _drop() {
        mark_to_drop(standard_metadata);  //丢弃
    }

    action forward_to_http(bit<9> port){
        standard_metadata.egress_spec = port
    }

    action forward_to_voip(bit<9> port){
        standard_metadata.egress_spec = port
    }

    action forward_to_other_service(bit<9> port){
        standard_metadata.egress_spec = port
    }

    
    // 定义五元组映射表
    table five_tuple_classifier {
        key = {
            meta.src_ip : lpm;  // 源IP地址
            meta.dst_ip : lpm;  // 目标IP地址
            meta.src_port : exact;  // 源端口
            meta.dst_port : exact;  // 目标端口
            meta.protocol : exact;  // 协议类型
        }
        actions = {
            forward_to_http;
            forward_to_voip;
            forward_to_other_service;
            drop;
        }
        size = 1024;  // 表的大小
    }

    
//---------------------------------------------------------------------       
    // SRv6 header插入ipv6 header
    action insert_srv6h_header(bit<8> num_segments) {
        hdr.srv6h.setValid();
        hdr.srv6h.next_hdr = hdr.ipv6.next_hdr;  //待定
        hdr.srv6h.hdr_ext_len =  (num_segments << 4) + 8;  
        hdr.srv6h.routing_type = 4;
        hdr.srv6h.segment_left = num_segments;
        hdr.srv6h.last_entry = num_segments - 1;
        hdr.srv6h.flags = 0;
        hdr.srv6h.tag = 0;
        //hdr.ipv6.next_hdr = PROTO_SRV6;
    }

   
    action srv6_t_insert_5(ipv6_addr_t s1, ipv6_addr_t s2, ipv6_addr_t s3, ipv6_addr_t s4, ipv6_addr_t s5) {
        hdr.ipv6.dst_addr = s1;
        hdr.ipv6.payload_len = hdr.ipv6.payload_len + 88;  //8+16*5=88
        insert_srv6h_header(5); //最多5跳，若少于5跳，后面的ipv6地址置0
        hdr.srv6_list[0].setValid();
        hdr.srv6_list[0].segment_id = s5;
        hdr.srv6_list[1].setValid();
        hdr.srv6_list[1].segment_id = s4;
        hdr.srv6_list[2].setValid();
        hdr.srv6_list[2].segment_id = s3;
        hdr.srv6_list[3].setValid();
        hdr.srv6_list[3].segment_id = s2;
        hdr.srv6_list[4].setValid();
        hdr.srv6_list[4].segment_id = s1;
    }


    action srv6_pop() {
      hdr.ipv6.next_hdr = hdr.srv6h.next_hdr;
      //bit<16> srv6h_size = ((bit<16>)hdr.srv6h.last_entry << 4) + 8;   //（last_entry+1）*16+8，last_entry记录list长度
      hdr.ipv6.payload_len = hdr.ipv6.payload_len - hdr.srv6h.hdr_ext_len;  //改变ipv6长度字段值

      hdr.srv6h.setInvalid();
      //将字段失效
      hdr.srv6_list[0].setInvalid();
      hdr.srv6_list[1].setInvalid();
      hdr.srv6_list[2].setInvalid();
      hdr.srv6_list[3].setInvalid();
      hdr.srv6_list[4].setInvalid();
    }


    table srv6_handle {      //插入和丢弃srv6头部
        key = {
           hdr.ipv6.dst_addr: lpm;       
        }
        actions = {
            srv6_t_insert_5;
            srv6_pop;
            NoAction;
        }
        default_action = NoAction;
        
        const entries ={
           (hdr.ipv6.dst_addr == 128'b0) : srv6_pop;
           default : srv6_t_insert_5;
        }
    }

    

//----------------------------------------
    // 简单的实现
    apply {
        five_tuple_classifier.apply();
        srv6_handle.apply();

    }
}


}
/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   ********************
*************************************************************************/
control c_egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {}
    }
}
/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   ***************
*************************************************************************/
control c_compute_checksum(inout headers  hdr,inout metadata meta) {
    apply {}
}
/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/
control Mydeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
        packet.emit(hdr.srv6h);
        packet.emit(hdr.srv6_list);
        
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/
V1Switch(
    MyParser(),
    c_verify_checksum(),
    Myingress(),
    c_egress(),
    c_compute_checksum(),
    Mydeparser()
) main;
