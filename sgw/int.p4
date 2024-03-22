//交换机的P4代码，支持INT和SRV6转发
/* -*- P4_16 -*- */                
#include <core.p4>
#include <v1model.p4>

#define MAX_PORTS 255
#define MAX_HOPS 5

const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86dd;
const bit<16> TYPE_ARP = 0x0806;
const bit<16> TYPE_PROBE = 0x0812;
const bit<8>  IP_PROTO_TCP = 8w6;
const bit<8>  IP_PROTO_UDP = 8w17;
const bit<8>  IP_PROTO_ICMP = 8w1;

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
header probe_header_t {
    bit<8> num_probe_data;    //记录这个探测包已经通过了几个交换机
}
header probe_data_t {
    bit<8>    swid;      //控制层告诉这个交换机自己的ID是多少
    bit<8>    ingress_port;
    bit<8>    egress_port;
    bit<32>   ingress_byte_cnt;
    bit<32>   egress_byte_cnt;
    bit<48>    ingress_last_time;
    bit<48>    ingress_cur_time;        //有些数据不用记录，但是为了看上去对称就都写了
    bit<48>    egress_last_time;
    bit<48>    egress_cur_time;
    bit<32>    ingress_packet_count;
    bit<32>    egress_packet_count;
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

struct metadata {
    /* empty */
    bit<8>   remaining1;
    bit<8>   remaining2;
    bit<8>   sswid;
    bit<32>  pktcont2;
    bit<9>   ingress_time;
    bit<8>   segment_left;
    bit<128> segment_id; 
}

header srv6h_t {
    bit<8> next_hdr;
    bit<8> hdr_ext_len;  //扩展头长度
    bit<8> routing_type;  //标识扩展包头类型，4表示为SRH
    bit<8> segment_left;  //用这个字段来确定解析时的segment list数量（对于普通数据包而言，最后一个交换机接收到这个数据包的时候会发现这个字段是0，但是对于INT数据包而言，最后一个交换机收到这个数据包会发现这个字段是1）
    bit<8> last_entry;   //最后一个seg list的索引
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
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}


struct headers {
    ethernet_t               ethernet;
    ipv6_h                   ipv6;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
    probe_header_t           probe_header;
    probe_data_t[MAX_HOPS]   probe_data;
    ipv4_t                   ipv4;
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
            TYPE_IPV4: parse_ipv4;    //说明这个包是从发端刚刚发出的，需要加东西（但是解析器到这里可以结束了）
            TYPE_IPV6: parse_ipv6;     //这个包可能是数据包，也可能是探测包，因为有了ipv6，后面一定会srv6h和五个srv6list（不管有没有数据）
            TYPE_PROBE: parse_probe;  //说明这个包是一个探测包，而且刚刚从发送端出来
            //TYPE_ARP: parse_arp;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);//情况1：得到了以太网头部+ipv4头部的包
        transition accept;
    }
    state parse_ipv6{
        packet.extract(hdr.ipv6);
        transition parse_srv6;
        
    }
    state parse_srv6 {
        packet.extract(hdr.srv6h);  //这里需要有判断segment list个数的方法
        //meta.last_entry = hdr.srv6h.last_entry; //判断segment list个数的方法
        //meta.segment_left = hdr.srv6h.segment_left; //剩余跳数，用这个值来判断是否丢弃srv6头部
        transition parse_srv6_list_1;
    }
    state parse_srv6_list_1 {
        packet.extract(hdr.srv6_list.next); //提取segment list的栈的第一个元素,循环解析srv6list，确保不丢失数据
        transition parse_srv6_list_2;       //得到以太网+ipv6+srv6h+srv6list+ipv4
                         
    }
    state parse_srv6_list_2{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6_list_3;
    }
    state parse_srv6_list_3{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6_list_4;
    }
    state parse_srv6_list_4{
        packet.extract(hdr.srv6_list.next);
        transition parse_srv6_list_5;
    }
    state parse_srv6_list_5{
        packet.extract(hdr.srv6_list.next);
        transition parse_middle;
    }
    state parse_probe {
        packet.extract(hdr.probe_header);
        meta.remaining1=hdr.probe_header.num_probe_data;
        transition select(hdr.probe_header.num_probe_data){
            0:accept;                           //情况2：得到了以太网+INT头部
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
}    //解析器完成，如上所示，现在这个解析器可以解析首个交换机收到的包：以太+ipv4数据包 以太+INT头部
  //中间交换机和尾部交换机可以解析收到的以太+ipv6+srv6h+srv6list（永远都是五个）+ipv4   以太+ipv6+srv6h+srv6list（永远五个）+INT头部+INTlist
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
                  inout standard_metadata_t standard_metadata){
    register<bit<32>>(MAX_PORTS) byte_cnt_reg;
    register<bit<32>>(MAX_PORTS) packet_cnt_reg;
    register<bit<48>>(MAX_PORTS) last_time_reg;
    action drop() {
        mark_to_drop(standard_metadata);
    }
    action ipv6_header_insert(bit<8> next_proto){//这个动作直接调用，如果发现这是第一个路由器就要用
        //ipv6头部插入
        hdr.ethernet.etherType = TYPE_IPV6;

        hdr.ipv6.setValid();
        // 设置IPv6头部字段
        hdr.ipv6.version = 6;  // IPv6版本
        hdr.ipv6.traffic_class = 0;  // 通信等级
        hdr.ipv6.flow_label = 0;  // 流标签
        hdr.ipv6.payload_len = 10;  // 负载长度
        hdr.ipv6.next_hdr = next_proto;  // 扩展头协议，43为SRV6数据包，44为INT数据包
        hdr.ipv6.hop_limit = 1;  // 跳数限制
        hdr.ipv6.src_addr = 100;  // 源地址
        hdr.ipv6.dst_addr = 80;  // 目标地址
    }
    action srv6_insert(bit<8> num_segments, bit<128> s1, bit<128> s2, bit<128> s3, bit<128> s4, bit<128> s5){
        //srv6 header插入,这个srv6head和body的插入需要调用表
        hdr.srv6h.setValid();
        hdr.srv6h.next_hdr = 2;  //待定
        hdr.srv6h.hdr_ext_len =  (num_segments << 4) + 8;  
        hdr.srv6h.routing_type = 4;
        hdr.srv6h.segment_left = num_segments;
        hdr.srv6h.last_entry = num_segments - 1;
        hdr.srv6h.flags = 0;
        hdr.srv6h.tag = 0;

        hdr.ipv6.payload_len = hdr.ipv6.payload_len + 88;  //8+16*5=88
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
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        
    }
    action srv6andipv6_abandon_set_only_for_information_packet() {
        hdr.ethernet.etherType = TYPE_IPV4;//这个动作直接调用

        hdr.ipv6.setInvalid();
        hdr.srv6h.setInvalid();
        hdr.srv6_list[0].setInvalid();
        hdr.srv6_list[1].setInvalid();
        hdr.srv6_list[2].setInvalid();
        hdr.srv6_list[3].setInvalid();
        hdr.srv6_list[4].setInvalid();   
    }
    action srv6andipv6_abandon_set_only_for_INT_packet() {
        hdr.ethernet.etherType = TYPE_PROBE;//这个动作直接调用

        hdr.ipv6.setInvalid();
        hdr.srv6h.setInvalid();
        hdr.srv6_list[0].setInvalid();
        hdr.srv6_list[1].setInvalid();
        hdr.srv6_list[2].setInvalid();
        hdr.srv6_list[3].setInvalid();
        hdr.srv6_list[4].setInvalid();   
    }
    action ipv6_forward(macAddr_t dstAddr, egressSpec_t port) {
        //ipv6_h_insert();
        //srv6_t_insert_5();
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;  

        //hdr.ipv6.payload_len = hdr.ipv6.payload_len - hdr.srv6h.hdr_ext_len;  //改变ipv6长度字段值
    }
    action srv6_forward() {
        hdr.srv6h.segment_left = hdr.srv6h.segment_left - 1;
        hdr.ipv6.dst_addr = hdr.srv6_list[0].segment_id;
        hdr.srv6_list.pop_front(1);
        hdr.srv6_list[4].setValid();
        //hdr.srv6_list[4] = 0;
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
    table ipv6_lpm_INT {
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
    table ipv6_lpm_INT_inteval {
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
    table srv6_handle_normal {     
        key = {
           hdr.ethernet.etherType: exact;       //第一个交换机中用，写一条流表项，键分别是ipv4的以太网类型
        }
        actions = {
            srv6_insert;
            drop;
        }
        default_action = drop();
        
    }
    table srv6_handle_INT {     
        key = {
           hdr.ethernet.etherType: exact;       //第一个交换机中用，写一条流表项，键分别是INT的以太网类型
        }
        actions = {
            srv6_insert;
            drop;
        }
        default_action = drop();
        
    }
    action set_swid(bit<8> swid) {
        hdr.probe_data[0].swid = swid;
    }

    table swid {
        key = {
           hdr.ethernet.etherType: exact;       //为swid表添加了对应的键，方便在实体机上运行
        }
        actions = {
            set_swid;
            NoAction;
        }
        default_action = NoAction();
    }
    apply{
        bit<32> packet_cnt;
        bit<32> new_packet_cnt;
        bit<32> byte_cnt;
        bit<32> new_byte_cnt;
        bit<48> last_time;
        bit<48> cur_time = standard_metadata.ingress_global_timestamp;
        byte_cnt_reg.read(byte_cnt, (bit<32>)standard_metadata.ingress_port);
        byte_cnt = byte_cnt + standard_metadata.packet_length;
        new_byte_cnt = (hdr.probe_header.isValid()) ? 0 : byte_cnt;
        byte_cnt_reg.write((bit<32>)standard_metadata.ingress_port, new_byte_cnt);
        
        packet_cnt_reg.read(packet_cnt, (bit<32>)standard_metadata.ingress_port);
        packet_cnt = packet_cnt + 1;
        new_packet_cnt = (hdr.probe_header.isValid()) ? 0 : packet_cnt;
        packet_cnt_reg.write((bit<32>)standard_metadata.ingress_port, new_packet_cnt);
        if(!hdr.probe_header.isValid()){//说明这是一个普通数据包（可能是已经插过头的，也可能是没插过头的）
            if(!hdr.srv6h.isValid()){    //说明这是一个刚刚从host1发出的信息包 
                srv6_handle_normal.apply();    //先插入srv6头部和body，这个时候以太网类型还是type_ipv4
                ipv6_header_insert(43);     //插入对应的IPv6头部
                ipv4_lpm.apply();     //先通过ipv4表确认这个信息包的发送端口（第一个交换机和最后一个交换机都会对信息包进行IPv4转发）

            }else{                     //说明这是一个已经插过srv6头的数据包（但是还不确定segment_left是多少）
                if(hdr.srv6h.segment_left == 0){ //这个segment_left=0说明现在接收到这个数据包的交换机是最后一台交换机。
                    srv6andipv6_abandon_set_only_for_information_packet();
                    ipv4_lpm.apply();
                }else{
                    srv6_forward();
                    ipv6_lpm.apply();
                } 

            }
        }
        else{    
            hdr.probe_data.push_front(1);
            hdr.probe_data[0].setValid();    //说明这就是一个INT包
            hdr.probe_header.num_probe_data=hdr.probe_header.num_probe_data+1;
            swid.apply();
            hdr.probe_data[0].ingress_port = (bit<8>)standard_metadata.ingress_port;
            hdr.probe_data[0].ingress_byte_cnt = byte_cnt;

            last_time_reg.read(last_time, (bit<32>)standard_metadata.ingress_port);
            last_time_reg.write((bit<32>)standard_metadata.ingress_port, cur_time);
            hdr.probe_data[0].ingress_last_time = last_time;
            hdr.probe_data[0].ingress_cur_time = cur_time;
            hdr.probe_data[0].ingress_packet_count = packet_cnt;
            if(!hdr.srv6h.isValid()){//这是一个从host1刚刚发出的探测包
                srv6_handle_INT.apply();    //先插入srv6头部和body，这个时候以太网类型还是type_ipv4
                ipv6_header_insert(44);
                srv6_forward();
                ipv6_lpm.apply();
            }
            else{
                if(hdr.srv6h.segment_left == 1){//探测包到了最后一个路由器
                    srv6_forward();
                    ipv6_lpm_INT.apply();
                    srv6andipv6_abandon_set_only_for_INT_packet();
                    
                    
                }else{
                    srv6_forward();
                    ipv6_lpm_INT_inteval.apply();
                }
            }
            }
        
        }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    register<bit<32>>(MAX_PORTS) byte_cnt_reg;
    register<bit<32>>(MAX_PORTS) packet_cnt_reg;
    register<bit<48>>(MAX_PORTS) last_time_reg;
    apply {    
        bit<32> packet_cnt;
        bit<32> new_packet_cnt;
        bit<32> byte_cnt;
        bit<32> new_byte_cnt;
        bit<48> last_time;
        bit<48> cur_time = standard_metadata.egress_global_timestamp;
        byte_cnt_reg.read(byte_cnt, (bit<32>)standard_metadata.egress_port);
        byte_cnt = byte_cnt + standard_metadata.packet_length;
        new_byte_cnt = (hdr.probe_header.isValid()) ? 0 : byte_cnt;
        byte_cnt_reg.write((bit<32>)standard_metadata.egress_port, new_byte_cnt);
        
        packet_cnt_reg.read(packet_cnt, (bit<32>)standard_metadata.egress_port);
        packet_cnt = packet_cnt + 1;
        new_packet_cnt = (hdr.probe_header.isValid()) ? 0 : packet_cnt;
        packet_cnt_reg.write((bit<32>)standard_metadata.egress_port, new_packet_cnt);
        if(hdr.probe_header.isValid()){
            hdr.probe_data[0].egress_port = (bit<8>)standard_metadata.egress_port;
            hdr.probe_data[0].egress_byte_cnt = byte_cnt;

            last_time_reg.read(last_time, (bit<32>)standard_metadata.egress_port);
            last_time_reg.write((bit<32>)standard_metadata.egress_port, cur_time);
            hdr.probe_data[0].egress_last_time = last_time;
            hdr.probe_data[0].egress_cur_time = cur_time;
            hdr.probe_data[0].egress_packet_count = packet_cnt;
        }
    }
}
/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
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
        packet.emit(hdr.ipv6);
        packet.emit(hdr.srv6h);
        packet.emit(hdr.srv6_list);
        packet.emit(hdr.probe_header);
        packet.emit(hdr.probe_data);
        packet.emit(hdr.ipv4);
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
