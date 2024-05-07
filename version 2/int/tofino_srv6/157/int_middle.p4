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
    bit<48> dstmacaddr;
    bit<48> srcmacaddr;
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
header udp_h {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<16>  hdr_length;
    bit<16>  checksum;
}

struct metadata {
    bit<8> segment_left;
    bit<8> num_segments;  //用于后面改变srv6长度，就是指定要加几个srv6list
    bit<8> trafficclass;   //服务等级
    bit<8> reminging;  
    bit<8> remaining1;
    bit<128> s1;
    bit<128> s2;
    bit<128> s3;
    bit<128> s4;
    bit<128> s5;
    bit<32> index;//用来判断这个接收到的数据包的srv6转发路径是对应数组的哪个位置
}

struct headers {
    ethernet_t               ethernet;
    arp_h                    arp;
    ipv6_h                   ipv6;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
    ipv4_t                   ipv4;
    tcp_h                    tcp;
    udp_h                    udp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/
/* parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata)  */
parser IngressParser(packet_in packet,
        /* User */    
        out headers hdr,
        out metadata meta,
        /* Intrinsic */
        out ingress_intrinsic_metadata_t ig_intr_md){
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
        transition accept;
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
        transition accept;
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
        transition accept;
    }

}    //解析器完成，如上所示，现在这个解析器可以解析收到的数据
/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

/* control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}     */

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control Ingress(inout headers hdr,
    inout metadata meta,
    /* Intrinsic */
    in ingress_intrinsic_metadata_t ig_intr_md,
    in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {

    action drop() {
        ig_intr_dprsr_md.drop_ctl = 1;
    }

   
    action ipv6_forward(bit<48> dstmacaddr,bit<9> port){
        //set the src mac address as the previous dst
        hdr.ethernet.srcmacaddr = hdr.ethernet.dstmacaddr;

       //set the destination mac address that we got from the match in the table
        hdr.ethernet.dstmacaddr = dstmacaddr;

        //set the output port that we also get from the table
        /* standard_metadata.egress_spec = port; */
        ig_intr_tm_md.ucast_egress_port = port;

    }
    action srv6forward_middle3_first(){
        hdr.ipv6.dst_addr=hdr.srv6_list[1].segment_id;
        hdr.srv6h.segment_left=hdr.srv6h.segment_left-1;
    }
    action srv6forward_middle4_first(){
        hdr.ipv6.dst_addr=hdr.srv6_list[2].segment_id;
        hdr.srv6h.segment_left=hdr.srv6h.segment_left-1;
    }
    action srv6forward_middle4_second(){
        hdr.ipv6.dst_addr=hdr.srv6_list[1].segment_id;
        hdr.srv6h.segment_left=hdr.srv6h.segment_left-1;
    }
    action srv6forward_middle5_first(){
        hdr.ipv6.dst_addr=hdr.srv6_list[3].segment_id;
        hdr.srv6h.segment_left=hdr.srv6h.segment_left-1;
    }
    action srv6forward_middle5_second(){
        hdr.ipv6.dst_addr=hdr.srv6_list[2].segment_id;
        hdr.srv6h.segment_left=hdr.srv6h.segment_left-1;
    }
    action srv6forward_middle5_third(){
        hdr.ipv6.dst_addr=hdr.srv6_list[1].segment_id;
        hdr.srv6h.segment_left=hdr.srv6h.segment_left-1;
    }
    table ipv6_lpm {
        key = {
            hdr.ipv6.dst_addr: exact;
        }
        actions = {
            ipv6_forward();
            drop();
        }
        default_action = drop();
    }
    apply {
        if (hdr.arp.isValid()) {
            hdr.ethernet.dstmacaddr = hdr.ethernet.srcmacaddr;
            hdr.ethernet.srcmacaddr = VIRTUAL_MAC;
            hdr.arp.OPER = 2;
            bit<32> temp_ip = hdr.arp.sender_ip;
            hdr.arp.sender_ip = hdr.arp.target_ip;
            hdr.arp.target_ip = temp_ip;
            hdr.arp.target_ha = hdr.arp.sender_ha;
            hdr.arp.sender_ha = VIRTUAL_MAC;
            ig_intr_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
        }else if (hdr.srv6h.isValid()){
            if(hdr.srv6h.last_entry==2){
                if(hdr.srv6h.segment_left==1){
                    srv6forward_middle3_first();
                }
            }else if(hdr.srv6h.last_entry==3){
                if(hdr.srv6h.segment_left==2){
                    srv6forward_middle4_first();
                }else if(hdr.srv6h.segment_left==1){
                    srv6forward_middle4_second();
                }
            }else if(hdr.srv6h.last_entry==4){
                if(hdr.srv6h.segment_left==3){
                    srv6forward_middle5_first();
                }else if(hdr.srv6h.segment_left==2){
                    srv6forward_middle5_second();
                }else if(hdr.srv6h.segment_left==1){
                    srv6forward_middle5_third();
                }
            }
            ipv6_lpm.apply();
        }
    }
}

control IngressDeparser(packet_out pkt,
        /* User */
        inout headers hdr,
        in metadata meta,
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
     
struct my_egress_headers_t {
}


struct egress_metadata_t {
}

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


Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;
