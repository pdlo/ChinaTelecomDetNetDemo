/* -*- P4_16 -*- */
#include <core.p4>
#include <tna.p4>

#define MAX_PORTS 255
#define MAX_HOPS 5

const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86dd;
const bit<16> TYPE_ARP = 0x0806;
const bit<8>  IP_PROTO_TCP = 8w6;
const bit<8>  IP_PROTO_UDP = 8w17;
const bit<8>  IP_PROTO_ICMP = 8w1;
const bit<48> VIRTUAL_MAC = 0x0a0a0a0a0a0a;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/


header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16>   etherType;
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

header probe_header_t {
    bit<8> num_probe_data;    //区分INT和普通数据包，记录INT抓了几组信息，目前而言，这个数只会有三种情况：0，1，2
}
header probe_data_t {
    bit<8>    swid;      //控制层告诉这个交换机自己的ID是多少
    bit<32>   byte_cnt;
    bit<32>   packet_cnt;
    bit<48>   last_time;
    bit<48>   cur_time;
}
header ipv6_h {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_len;  //记录载荷长（包括srh长度）
    bit<8>   next_hdr;  //IPV6基本报头后的那一个扩展包头的信息类型，SRH定为43，43就表明这是一个普通数据包，44表明这是一个INT包
    bit<8>   hop_limit;
    bit<128> src_addr;
    bit<128> dst_addr;
}  //需要ipv6的某一个字段来判断扩展头是否为srv6扩展头


header srv6h_t {
    bit<8> next_hdr;
    bit<8> hdr_ext_len;  //扩展头长度
    bit<8> routing_type;  //标识扩展包头类型，4表示为SRH
    bit<8> segment_left;  //如果是srv6经过四跳，这个sl刚开始的值就是3，每经过一跳减一
    bit<8> last_entry;   //srv6list的最后一个索引是多少，四跳这个字段就是3，五跳这个字段就是4，这个字段的值确定下来后在传输的过程中不会发送改变
    bit<8> flags;
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
    bit<32> srcAddr;
    bit<32> dstAddr;
}

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

struct ingress_metadata {
    bit<8> segment_left;
    bit<8> num_segments;  //用于后面改变srv6长度，就是指定要加几个srv6list
    bit<8> trafficclass;   //服务等级
    bit<16> reminging;  //用来在提取srv6list的时候作为中介
    bit<8> remaining1;//用来在提取prodadata的时候作为中介
   /*  bit<8> the_type_of_route_this_packet_choose; //来表明这个包走的具体路径，以便后面知道往寄存器的哪一个地方填信息 */
    bit<128> s1;
    bit<128> s2;
    bit<128> s3;
    bit<128> s4;
    bit<128> s5;
    bit<32> index;//用来判断这个接收到的数据包的srv6转发路径是对应数组的哪个位置
}

struct ingress_headers {
    ethernet_t               ethernet;
    arp_h                    arp;
    ipv6_h                   ipv6;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
    probe_header_t           probe_header;
    probe_data_t[MAX_HOPS]   probe_data;
    ipv4_t                   ipv4;
    tcp_h                    tcp;
    udp_h                    udp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/
parser IngressParser(packet_in packet,
                out ingress_headers hdr,
                out ingress_metadata meta,
                out ingress_intrinsic_metadata_t ig_intr_md) {

    state start {
        meta = {0,0,0,0,0,0,0,0,0,0,0};
        packet.extract(ig_intr_md);
        packet.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;    //说明这个数据包是从发端刚刚发出的。
            TYPE_IPV6: parse_ipv6;     //这个包可能是数据包，也可能是探测包，因为有了ipv6，后面一定会srv6h和last_entry个list
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
        transition select(hdr.ipv4.protocol) {
            IP_PROTO_TCP: parse_tcp;
            IP_PROTO_UDP: parse_udp;
            default: accept;
        }
    }
    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        packet.extract(hdr.udp);
        transition accept;
    }
    state parse_ipv6{
        packet.extract(hdr.ipv6);
        transition parse_srv6;
        
    }
    state parse_srv6{
        packet.extract(hdr.srv6h);
        meta.segment_left=hdr.srv6h.segment_left;
        transition select(hdr.srv6h.last_entry){
            2:parse_srv6list_3_1;
            3:parse_srv6list_4_1;
            4:parse_srv6list_5_1;
            default: accept;
        }
    }
    state parse_srv6list_3_1{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_3_2;
    }
    state parse_srv6list_3_2{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_3_3;
    }
     state parse_srv6list_3_3{
        packet.extract(hdr.srv6_list.next);
        transition middle;
    }
    state parse_srv6list_4_1{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_4_2;
    }
    state parse_srv6list_4_2{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_4_3;
    }
    state parse_srv6list_4_3{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_4_4;
    }
    state parse_srv6list_4_4{
        packet.extract(hdr.srv6_list.next);
        transition middle;
    }
    state parse_srv6list_5_1{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_5_2;
    }
    state parse_srv6list_5_2{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_5_3;
    }
    state parse_srv6list_5_3{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_5_4;
    }
    state parse_srv6list_5_4{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6list_5_5;
    }
    state parse_srv6list_5_5{
        packet.extract(hdr.srv6_list.next);
        transition middle;
    }
    state parse_probe {
        packet.extract(hdr.probe_header);
       /*  meta.remaining1=hdr.probe_header.num_probe_data; */
        transition select(hdr.probe_header.num_probe_data){
            0:accept;    
            1:parse_probe_list_1_1;
            2:parse_probe_list_2_1;                      //说明INT包刚刚从发送端发出
        }
    }
    state parse_probe_list_1_1{
        packet.extract(hdr.probe_data.next);
        transition accept;
    }
    state parse_probe_list_2_1{
        packet.extract(hdr.probe_data.next);
        transition parse_probe_list_2_2;
    }
    state parse_probe_list_2_2{
        packet.extract(hdr.probe_data.next);
        transition accept;
    }
    state middle{
        transition select(hdr.srv6h.next_hdr){
            4:parse_ipv4;
            150:parse_probe;
            default:accept;
        }
    }
}  

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control Ingress(inout ingress_headers hdr,
                inout ingress_metadata meta,
                in ingress_intrinsic_metadata_t ig_intr_md,
                in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
                inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
                inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md){
    action drop() {
        ig_intr_dprsr_md.drop_ctl = 1;
    }
    action srv6_insert(bit<8> num_segments, bit<8> last_entry,
        bit<128> s1, bit<128> s2, bit<128> s3, bit<128> s4, bit<128> s5){
                //这个插头动作只会对数据包使用，有几个srv6_list就写x-1个last_entry
        hdr.ethernet.etherType = TYPE_IPV6;//有几个srv6_list（x），就会有x个num_segments，x-1个segment_left

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
        hdr.srv6h.next_hdr = 4;  //1为icmp,2为IGMP，6为TCP协议，17为UDP，4为ipv4，41为ipv6
        hdr.srv6h.hdr_ext_len = 88;
        hdr.srv6h.routing_type = 4;
        hdr.srv6h.segment_left = num_segments;
        hdr.srv6h.last_entry = last_entry;
        hdr.srv6h.flags = 0;
        hdr.srv6h.tag = 0;

        hdr.ipv6.payload_len = hdr.ipv4.totalLen + 88; 

        meta.num_segments = num_segments;

        meta.s1 = s1;
        meta.s2 = s2;
        meta.s3 = s3;
        meta.s4 = s4;
        meta.s5 = s5;

    }

    action get_traffic_class(bit<8> trafficclass) {
        //根据流表下发的等级来判断,默认为0，如果有流表，则等级为1
        meta.trafficclass = trafficclass; 
    }
   /*  action determine_the_index_of_packet(bit<32> target){
        meta.index=target;
    }
     */
    action srv6andipv6_abandon() {
        hdr.ethernet.etherType = TYPE_IPV4;//这个动作直接调用
        hdr.ipv6.setInvalid();//对于数据包先去除ipv6和srv6头部，之后再去除list部分
        hdr.srv6h.setInvalid();
        
    }
  
    action ipv6_forward(bit<48> dstmacaddr,bit<9> port) {
        ig_intr_tm_md.ucast_egress_port = port;
        hdr.ethernet.srcAddr=hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr=dstmacaddr;
    }
    //总共srv6list会是3，4，5，对于首尾两个交换机而言，尾部交换机收到的SG肯定是0，而头部交换机收到的sg可能是2，3，4
    action srv6_forward_start_for_3list() {
        hdr.ipv6.dst_addr = hdr.srv6_list[2].segment_id;
        hdr.srv6h.segment_left = hdr.srv6h.segment_left - 1;
    }
    action srv6_forward_start_for_4list() {
        hdr.ipv6.dst_addr = hdr.srv6_list[3].segment_id;
        hdr.srv6h.segment_left = hdr.srv6h.segment_left - 1;
    }
    action srv6_forward_start_for_5list() {
        hdr.ipv6.dst_addr = hdr.srv6_list[4].segment_id;
        hdr.srv6h.segment_left = hdr.srv6h.segment_left - 1;
    }
    action srv6_forward_for_last_packet(){
        hdr.ipv6.dst_addr = hdr.srv6_list[0].segment_id;
    }
    table ipv6_lpm_normal_start {
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
    table ipv6_lpm_normal_end {
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

    table ipv6_lpm_INT{
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
    table ipv6_lpm_INT_end {
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
    table select_traffic_class{
        key = {
            hdr.ipv4.dstAddr: exact;
            hdr.ipv4.srcAddr: exact;
            hdr.tcp.dst_port: exact;
        }
        actions = {
            get_traffic_class;
        }
        default_action = get_traffic_class(0);
    }
     table select_srv6_path {      
        //插入srv6头部
        key = {
            hdr.ipv4.dstAddr: lpm;   //目的ipv4
            meta.trafficclass: exact;   //流等级       
        }
        actions = {
            srv6_insert;
            drop;
        }
        default_action = drop();   
    }
    apply{
        if (hdr.arp.isValid()) {
            hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
            hdr.ethernet.srcAddr = VIRTUAL_MAC;
            hdr.arp.OPER = 2;
            bit<32> temp_ip = hdr.arp.sender_ip;
            hdr.arp.sender_ip = hdr.arp.target_ip;
            hdr.arp.target_ip = temp_ip;
            hdr.arp.target_ha = hdr.arp.sender_ha;
            hdr.arp.sender_ha = VIRTUAL_MAC;
            ig_intr_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        }
        if(hdr.ipv4.isValid()){        //说明这是一个数据包
            if(!hdr.srv6h.isValid()){  //这是一个刚刚从发送端发过来的数据包
                if(hdr.tcp.isValid()){
                    select_traffic_class.apply();
                }else{
                    meta.trafficclass=0;
                }
            select_srv6_path.apply();
            if(meta.num_segments==4){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s4;

                hdr.srv6_list[1].setValid();
                hdr.srv6_list[1].segment_id = meta.s3;

                hdr.srv6_list[2].setValid();
                hdr.srv6_list[2].segment_id = meta.s2;

                hdr.srv6_list[3].setValid();
                hdr.srv6_list[3].segment_id = meta.s1;
            }else if(meta.num_segments==5){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s5;

                hdr.srv6_list[1].setValid();
                hdr.srv6_list[1].segment_id = meta.s4;

                hdr.srv6_list[2].setValid();
                hdr.srv6_list[2].segment_id = meta.s3;

                hdr.srv6_list[3].setValid();
                hdr.srv6_list[3].segment_id = meta.s2;

                hdr.srv6_list[4].setValid();
                hdr.srv6_list[4].segment_id = meta.s1; 
            }else if(meta.num_segments==3){
                hdr.srv6_list[0].setValid();
                hdr.srv6_list[0].segment_id = meta.s3;

                hdr.srv6_list[1].setValid();
                hdr.srv6_list[1].segment_id = meta.s2;

                hdr.srv6_list[2].setValid();
                hdr.srv6_list[2].segment_id = meta.s1;
            }
            if(hdr.srv6h.segment_left==2){
                srv6_forward_start_for_3list();
            }else if(hdr.srv6h.segment_left==3){
                srv6_forward_start_for_4list();
            }else if(hdr.srv6h.segment_left==4){
                srv6_forward_start_for_5list();
            }
            ipv6_lpm_normal_start.apply();
            }else if(hdr.srv6h.isValid()&&hdr.srv6h.segment_left==0)
                {//说明这是一个末尾数据包
                    srv6_forward_for_last_packet();
                    ipv6_lpm_normal_end.apply();
                    if(hdr.srv6h.last_entry==3){
                        hdr.srv6_list[0].setInvalid();
                        hdr.srv6_list[1].setInvalid();
                        hdr.srv6_list[2].setInvalid();
                        hdr.srv6_list[3].setInvalid();
                    }else if(hdr.srv6h.last_entry==4){
                        hdr.srv6_list[0].setInvalid();
                        hdr.srv6_list[1].setInvalid();
                        hdr.srv6_list[2].setInvalid();
                        hdr.srv6_list[3].setInvalid();
                        hdr.srv6_list[4].setInvalid();
                    }else if(hdr.srv6h.last_entry==2){
                        hdr.srv6_list[0].setInvalid();
                        hdr.srv6_list[1].setInvalid();
                        hdr.srv6_list[2].setInvalid();
                    }
                    srv6andipv6_abandon();
                }

            }
        else if(hdr.probe_header.isValid()){//这是一个INT包
            if(hdr.srv6h.segment_left!=0){
                if(hdr.srv6h.segment_left==2){
                    srv6_forward_start_for_3list();
                }else if(hdr.srv6h.segment_left==3){
                    srv6_forward_start_for_4list();
                }else if(hdr.srv6h.segment_left==4){
                    srv6_forward_start_for_5list();
                }
                ipv6_lpm_INT.apply();
            }
            if(hdr.srv6h.segment_left==0){
                srv6_forward_for_last_packet();
                ipv6_lpm_INT_end.apply();
            }
        } 

    }
}

control IngressDeparser(packet_out pkt,
        /* User */
        inout ingress_headers hdr,
        in ingress_metadata meta,
        /* Intrinsic */
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md)
{
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.arp);
        pkt.emit(hdr.ipv6);
        pkt.emit(hdr.srv6h);
        pkt.emit(hdr.srv6_list);
        pkt.emit(hdr.probe_header);
        pkt.emit(hdr.probe_data);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.udp);
    }
}

struct egress_metadata {
}

struct egress_headers {
}


parser EgressParser(packet_in packet,
     /* User */
     out egress_headers hdr,
     out egress_metadata meta,
     /* Intrinsic */
     out egress_intrinsic_metadata_t eg_intr_md)
{
   state start {
        packet.extract(eg_intr_md);
        transition accept;
    }
    
}


control Egress(inout egress_headers hdr,
                inout egress_metadata meta,
                in egress_intrinsic_metadata_t eg_intr_md,
                in egress_intrinsic_metadata_from_parser_t eg_intr_prsr_md,
                inout egress_intrinsic_metadata_for_deparser_t eg_intr_dprsr_md,
                inout egress_intrinsic_metadata_for_output_port_t eg_intr_tm_md
                ) {
                apply{

                }
        
                }





control EgressDeparser(packet_out pkt,
    /* User */
    inout egress_headers hdr,
    in egress_metadata meta,
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
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;
