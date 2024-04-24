/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define MAX_PORTS 255
#define MAX_HOPS 40

const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86dd;
const bit<16> TYPE_ARP = 0x0806;
const bit<8>  IP_PROTO_TCP = 8w6;
const bit<8>  IP_PROTO_UDP = 8w17;
const bit<8>  IP_PROTO_ICMP = 8w1;


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
header udp_h {
    bit<16>  src_port;
    bit<16>  dst_port;
    bit<16>  hdr_length;
    bit<16>  checksum;
}

struct metadata {
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
    probe_header_t           probe_header;
    probe_data_t[MAX_HOPS]   probe_data;
    ipv4_t                   ipv4;
    tcp_h                    tcp;
    udp_h                    udp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
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
    state parse_srv6 {
        packet.extract(hdr.srv6h);  //这里需要有判断提取几个srv6list的方法
        meta.reminging=hdr.srv6h.last_entry;
        meta.reminging=meta.reminging+1;
        transition parse_srv6_list;
    }
    state parse_srv6_list{
        packet.extract(hdr.srv6_list.next);
        meta.reminging=meta.reminging-1;
        transition select(meta.reminging){
            0: parse_middle;
            default: parse_srv6_list;
        }
    }
  
    state parse_probe {
        packet.extract(hdr.probe_header);
        meta.remaining1=hdr.probe_header.num_probe_data;
        transition select(hdr.probe_header.num_probe_data){
            0:accept;                           //说明INT包刚刚从发送端发出
            default:parse_probe_list;
        }
    }
    state parse_probe_list{
        packet.extract(hdr.probe_data.next);
        meta.remaining1=meta.remaining1-1;
        transition select(meta.remaining1){
            0:accept;
            default: parse_probe_list;
        }
    }
    state parse_middle{
        transition select(hdr.ipv6.next_hdr){
            43:parse_ipv4;
            44:parse_probe;
            default:accept;
        }
    }
}    //解析器完成，如上所示，现在这个解析器可以解析收到的数据
/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}    

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop(standard_metadata);
    }

   
    action ipv6_forward(bit<48> dstAddr,bit<9> port){
        //set the src mac address as the previous dst
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;

       //set the destination mac address that we got from the match in the table
        hdr.ethernet.dstAddr = dstAddr;

        //set the output port that we also get from the table
        standard_metadata.egress_spec = port;

    }
    action srv6forward(){
        hdr.ipv6.dst_addr=hdr.srv6_list[hdr.srv6h.segment_left].segment_id;
        hdr.srv6h.segment_left=hdr.srv6h.segment_left-1;
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
        default_action = drop();
    }
    table srv6_forward {
        key = {
            hdr.ethernet.etherType: exact;
        }
        actions = {
            srv6forward();
            drop;
            //NoAction;
        }
        size = 1024;
        default_action = drop();
    }
    apply {

        //only if IPV4 the rule is applied. Therefore other packets will not be forwarded.
        if (hdr.srv6h.isValid()){
            /* hdr.ipv6.dst_addr=hdr.srv6_list[hdr.srv6h.segment_left].segment_id;
            hdr.srv6h.segment_left=hdr.srv6h.segment_left-1; */ 
            srv6_forward.apply();
            ipv6_lpm.apply();

        }
    }
}
        

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.arp);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.srv6h);
        packet.emit(hdr.srv6_list);
        packet.emit(hdr.probe_header);
        packet.emit(hdr.probe_data);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
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
