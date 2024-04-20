/* -*- P4_16 -*- */
#include <core.p4>
#include <tna.p4>

#define MAX_PORTS 255
#define MAX_HOPS 40

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
    bit<8> num_segments;  //用于后面改变srv6长度，就是指定要加几个srv6list
    bit<8> trafficclass;   //服务等级
    bit<8> reminging;  //用来在提取srv6list的时候作为中介
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
        meta = {0,0,0,0,0,0,0,0,0,0};
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
    /* register<bit<32>>(50) byte_cnt_reg;  
    register<bit<32>>(50) packet_cnt_reg;
    register<bit<48>>(50) last_time_reg; */
    //字节计数器
    Register <bit<32>,bit<32>>(50,0) byte_cnt_reg;
    RegisterAction<bit<32>,bit<32>,bit<32>>(byte_cnt_reg) byte_cnt_reg_accumulate = {
        void apply(inout bit<32> byte_cnt,out bit<32> read_val){
            byte_cnt=byte_cnt+ig_intr_md.pkt_length;
        }
    };
    RegisterAction<bit<32>,bit<32>,bit<32>>(byte_cnt_reg) byte_cnt_reg_read = {
        void apply(inout bit<32> byte_cnt,out bit<32> read_val){
            read_val=byte_cnt;
            byte_cnt=0;
        }
    };
    //个数计数器
    Register <bit<32>,bit<32>>(50,0) packet_cnt_reg;
    RegisterAction<bit<32>,bit<32>,bit<32>>(packet_cnt_reg) packet_cnt_reg_accumulate = {
        void apply(inout bit<32> packet_cnt,out bit<32> read_val){
            packet_cnt=packet_cnt+1;
        }
    };
    RegisterAction<bit<32>,bit<32>,bit<32>>(packet_cnt_reg) packet_cnt_reg_read = {
        void apply(inout bit<32> packet_cnt,out bit<32> read_val){
            read_val=packet_cnt;
            packet_cnt=0;
        }
    };
    //时间计数器
    Register <bit<48>,bit<32>>(50,0) last_time_reg;
    RegisterAction<bit<48>,bit<32>,bit<48>>(last_time_reg) last_time_reg_read = {
        void apply(inout bit<48> last_time,out bit<48> read_val){
            read_val=last_time;
        }
    };
    RegisterAction<bit<48>,bit<32>,bit<48>>(last_time_reg) last_time_reg_update = {
        void apply(inout bit<48> last_time,out bit<48> read_val){
            last_time=ig_intr_prsr_md.global_tstamp;
        }
    };
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
        hdr.srv6h.segment_left = num_segments-1;
        hdr.srv6h.last_entry = last_entry;
        hdr.srv6h.flags = 0;
        hdr.srv6h.tag = 0;


        hdr.ipv6.payload_len = hdr.ipv4.totalLen + 88;  //8+16*5=88

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
    action determine_the_index_of_packet(bit<32> target){
        meta.index=target;
    }
    
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
    action srv6_forward() {
        hdr.ipv6.dst_addr = hdr.srv6_list[hdr.srv6h.segment_left].segment_id;
        hdr.srv6h.segment_left = hdr.srv6h.segment_left - 1;
    }
    action srv6_forward_for_last_packet(){
        hdr.ipv6.dst_addr = hdr.srv6_list[hdr.srv6h.segment_left].segment_id;
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
    action set_swid(bit<8> swid) {
        hdr.probe_data[0].swid = swid;
    }

    table swid_single {
    	key = {
           hdr.ethernet.etherType: exact;       //第一个交换机中用，写一条流表项，键分别是INT的以太网类型/////change!!!!!!
        }
        actions = {
            set_swid;
            NoAction;
        }
        default_action = NoAction();
    }
    table swid_both {
    	key = {
           hdr.ethernet.etherType: exact;       //第一个交换机中用，写一条流表项，键分别是INT的以太网类型/////change!!!!!!
        }
        actions = {
            set_swid;
            NoAction;
        }
        default_action = NoAction();
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
    table which_array_to_fill_for_five_list_INT{
        key ={
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet;
            drop;
        }
        default_action = drop();  
    }
    table which_array_to_fill_for_five_list_normal{
        key ={
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet;
            drop;
        }
        default_action = drop();  
    }
    table which_array_to_fill_for_four_list_normal{
        key ={
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet;
            drop;
        }
        default_action = drop();  
    }

    table which_array_to_fill_for_three_list_normal{
        key ={
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet;
            drop;
        }
        default_action = drop();  
    }
    table which_array_to_fill_for_four_list_INT{
        key ={
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet();
            drop();
        }
        default_action = drop();  
    }
    table which_array_to_fill_for_three_list_INT{
        key ={
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet();
            drop();
        }
        default_action = drop();  
    }
    table both_direction_for_INT_six_list_ingress{
        key ={
            hdr.srv6_list[6].segment_id:exact;
            hdr.srv6_list[5].segment_id:exact;
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet();
            drop();
        }
        default_action = drop();  
    }

    table both_direction_for_INT_eight_list_ingress{
        key ={
            hdr.srv6_list[8].segment_id:exact;
            hdr.srv6_list[7].segment_id:exact;
            hdr.srv6_list[6].segment_id:exact;
            hdr.srv6_list[5].segment_id:exact;
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet();
            drop();
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
            srv6_forward();
            ipv6_lpm_normal_start.apply();
            }else if(hdr.srv6h.isValid()&&hdr.srv6h.segment_left==0)
                {//说明这是一个末尾数据包
                    srv6_forward_for_last_packet();
                    ipv6_lpm_normal_end.apply();
                    /* bit<32> packet_length;
                    bit<32> new_packet_length;
                    bit<32> packet_count;
                    bit<32> new_packet_count; */
                    if(hdr.srv6h.last_entry==3){
                        which_array_to_fill_for_four_list_normal.apply();
                    }else if(hdr.srv6h.last_entry==4){
                        which_array_to_fill_for_five_list_normal.apply();
                    }else if(hdr.srv6h.last_entry==2){
                        which_array_to_fill_for_three_list_normal.apply();
                    }
                   /*  byte_cnt_reg.read(packet_length,meta.index);
                    new_packet_length=packet_length+standard_metadata.packet_length;
                    byte_cnt_reg.write(meta.index,new_packet_length);

                    packet_cnt_reg.read(packet_count,meta.index);
                    new_packet_count=packet_count+1;
                    packet_cnt_reg.write(meta.index,new_packet_count); */
                    byte_cnt_reg_accumulate.execute(meta.index);
                    packet_cnt_reg_accumulate.execute(meta.index);
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
            if(hdr.srv6h.last_entry==6 || hdr.srv6h.last_entry==8){   ////   4对7对6，5对9对8说明这是一个走来回的探测包，来回走的探测包有讲究，要在四个地方抓数据
                if((hdr.srv6h.last_entry==6 && hdr.srv6h.segment_left==3)||(hdr.srv6h.last_entry==6 && hdr.srv6h.segment_left==0)){
                    both_direction_for_INT_six_list_ingress.apply();
                }else if((hdr.srv6h.last_entry==8 && hdr.srv6h.segment_left==4)||(hdr.srv6h.last_entry==8 && hdr.srv6h.segment_left==0)){
                    both_direction_for_INT_eight_list_ingress.apply();   
                }
                if((hdr.srv6h.last_entry==6&&hdr.srv6h.segment_left!=6)||(hdr.srv6h.last_entry==8&&hdr.srv6h.segment_left!=8)){
                    hdr.probe_data.push_front(1);
                    hdr.probe_data[0].setValid(); 
                    swid_both.apply();
                    hdr.probe_header.num_probe_data=hdr.probe_header.num_probe_data+1;
                    /* bit<32> packet_length;
                    bit<32> packet_count;
                    bit<48> last_time; */
                    /* bit<48> cur_time; */
                    /* cur_time=ig_intr_prsr_md.global_tstamp; */
                    /* last_time_reg.read(last_time,meta.index); */
                    hdr.probe_data[0].cur_time=ig_intr_prsr_md.global_tstamp;
                    hdr.probe_data[0].last_time=last_time_reg_read.execute(meta.index);
                    last_time_reg_update.execute(meta.index);

                    hdr.probe_data[0].packet_cnt=packet_cnt_reg_read.execute(meta.index);
                    
                    hdr.probe_data[0].byte_cnt=byte_cnt_reg_read.execute(meta.index);

                }
            }else if(hdr.srv6h.last_entry==3 || hdr.srv6h.last_entry==4||hdr.srv6h.last_entry==2){   //说明这是一个单向INT包
                if(hdr.srv6h.last_entry==3 && hdr.srv6h.segment_left==0){
                    which_array_to_fill_for_four_list_INT.apply();
                }else if(hdr.srv6h.last_entry==4 && hdr.srv6h.segment_left==0){
                    which_array_to_fill_for_five_list_INT.apply();
                }else if(hdr.srv6h.last_entry==2&&hdr.srv6h.segment_left==0){
                    which_array_to_fill_for_three_list_INT.apply();
                }
                if((hdr.srv6h.last_entry==4&&hdr.srv6h.segment_left!=4)||(hdr.srv6h.last_entry==3&&hdr.srv6h.segment_left!=3)||(hdr.srv6h.last_entry==2&&hdr.srv6h.segment_left!=2)){
                    hdr.probe_data.push_front(1);
                    hdr.probe_data[0].setValid(); 
                    swid_single.apply();
                    hdr.probe_header.num_probe_data=hdr.probe_header.num_probe_data+1;
                    hdr.probe_data[0].cur_time=ig_intr_prsr_md.global_tstamp;
                    hdr.probe_data[0].last_time=last_time_reg_read.execute(meta.index);
                    last_time_reg_update.execute(meta.index);

                    hdr.probe_data[0].packet_cnt=packet_cnt_reg_read.execute(meta.index);
                    
                    hdr.probe_data[0].byte_cnt=byte_cnt_reg_read.execute(meta.index);
                    /* bit<32> packet_length;
                    bit<32> packet_count;
                    bit<48> last_time;
                    bit<48> cur_time;
                    cur_time=standard_metadata.ingress_global_timestamp;
                    last_time_reg.read(last_time,meta.index);
                    hdr.probe_data[0].cur_time=cur_time;
                    hdr.probe_data[0].last_time=last_time;
                    last_time_reg.write(meta.index,cur_time);

                    packet_cnt_reg.read(packet_count,meta.index);
                    hdr.probe_data[0].packet_cnt=packet_count;
                    packet_cnt_reg.write(meta.index,0);

                    byte_cnt_reg.read(packet_length,meta.index);
                    hdr.probe_data[0].byte_cnt=packet_length;
                    byte_cnt_reg.write(meta.index,0);   */
                }
            }
            if(hdr.srv6h.segment_left!=0){
                srv6_forward();
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
    bit<8> num_segments;  //用于后面改变srv6长度，就是指定要加几个srv6list
    bit<8> trafficclass;   //服务等级
    bit<8> reminging;  //用来在提取srv6list的时候作为中介
    bit<8> remaining1;//用来在提取prodadata的时候作为中介
   /*  bit<8> the_type_of_route_this_packet_choose; //来表明这个包走的具体路径，以便后面知道往寄存器的哪一个地方填信息 */
    bit<128> s1;
    bit<128> s2;
    bit<128> s3;
    bit<128> s4;
    bit<128> s5;
    bit<32> index;//用来判断这个接收到的数据包的srv6转发路径是对应数组的哪个位置
}

struct egress_headers {
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

parser EgressParser(packet_in packet,
     /* User */
     out egress_headers hdr,
     out egress_metadata meta,
     /* Intrinsic */
     out egress_intrinsic_metadata_t eg_intr_md)
{
   state start {
        meta = {0,0,0,0,0,0,0,0,0,0};
        packet.extract(eg_intr_md);
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
        transition select(hdr.srv6h.next_hdr){
            4:parse_ipv4;
            150:parse_probe;
            default:accept;
        }
    }
}


control Egress(inout egress_headers hdr,
                inout egress_metadata meta,
                in egress_intrinsic_metadata_t eg_intr_md,
                in egress_intrinsic_metadata_from_parser_t eg_intr_prsr_md,
                inout egress_intrinsic_metadata_for_deparser_t eg_intr_dprsr_md,
                inout egress_intrinsic_metadata_for_output_port_t eg_intr_tm_md
                ) {
    /* register<bit<32>>(50) byte_cnt_reg;
    register<bit<32>>(50) packet_cnt_reg;
    register<bit<48>>(50) last_time_reg; */
    Register <bit<32>,bit<32>>(50,0) byte_cnt_reg_out;
    RegisterAction<bit<32>,bit<32>,bit<32>>(byte_cnt_reg_out) byte_cnt_reg_accumulate_out = {
        void apply(inout bit<32> byte_cnt,out bit<32> read_val){
            byte_cnt=byte_cnt+eg_intr_md.pkt_length;
        }
    };
    RegisterAction<bit<32>,bit<32>,bit<32>>(byte_cnt_reg_out) byte_cnt_reg_read_out = {
        void apply(inout bit<32> byte_cnt,out bit<32> read_val){
            read_val=byte_cnt;
            byte_cnt=0;
        }
    };
    //个数计数器
    Register <bit<32>,bit<32>>(50,0) packet_cnt_reg_out;
    RegisterAction<bit<32>,bit<32>,bit<32>>(packet_cnt_reg_out) packet_cnt_reg_accumulate_out = {
        void apply(inout bit<32> packet_cnt,out bit<32> read_val){
            packet_cnt=packet_cnt+1;
        }
    };
    RegisterAction<bit<32>,bit<32>,bit<32>>(packet_cnt_reg_out) packet_cnt_reg_read_out = {
        void apply(inout bit<32> packet_cnt,out bit<32> read_val){
            read_val=packet_cnt;
            packet_cnt=0;
        }
    };
    //时间计数器
    Register <bit<48>,bit<32>>(50,0) last_time_reg_out;
    RegisterAction<bit<48>,bit<32>,bit<48>>(last_time_reg_out) last_time_reg_read_out = {
        void apply(inout bit<48> last_time,out bit<48> read_val){
            read_val=last_time;
        }
    };
    RegisterAction<bit<48>,bit<32>,bit<48>>(last_time_reg_out) last_time_reg_update_out = {
        void apply(inout bit<48> last_time,out bit<48> read_val){
            last_time=eg_intr_prsr_md.global_tstamp;
        }
    };
    action drop_out() {
        eg_intr_dprsr_md.drop_ctl=1;
    }
    action determine_the_index_of_packet_out(bit<32> target){
        meta.index=target;
    }
    action set_swid_out(bit<8> swid) {
        hdr.probe_data[0].swid = swid;
    }
    table both_direction_for_INT_six_list_egress{
        key ={
            hdr.srv6_list[6].segment_id:exact;
            hdr.srv6_list[5].segment_id:exact;
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }

    table both_direction_for_INT_eight_list_egress{
        key ={
            hdr.srv6_list[8].segment_id:exact;
            hdr.srv6_list[7].segment_id:exact;
            hdr.srv6_list[6].segment_id:exact;
            hdr.srv6_list[5].segment_id:exact;
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }
    table which_array_to_fill_for_five_list_out_INT{
        key ={
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }
    table which_array_to_fill_for_three_list_out_INT{
        key ={
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }
    table which_array_to_fill_for_five_list_out_normal{
        key ={
            hdr.srv6_list[4].segment_id:exact;
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }
    table which_array_to_fill_for_three_list_out_normal{
        key ={
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }
    table which_array_to_fill_for_four_list_out_INT{
        key ={
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }
    table which_array_to_fill_for_four_list_out_normal{
        key ={
            hdr.srv6_list[3].segment_id:exact;
            hdr.srv6_list[2].segment_id:exact;
            hdr.srv6_list[1].segment_id:exact;
            hdr.srv6_list[0].segment_id:exact;
        }
        actions = {
            determine_the_index_of_packet_out();
            drop_out();
        }
        default_action = drop_out();  
    }
    table swid_out_single {
    	key = {
           hdr.ethernet.etherType: exact;       //第一个交换机中用，写一条流表项，键分别是INT的以太网类型/////change!!!!!!
        }
        actions = {
            set_swid_out();
            NoAction;
        }
        default_action = NoAction();
    }
    table swid_out_both{
    	key = {
           hdr.ethernet.etherType: exact;       //第一个交换机中用，写一条流表项，键分别是INT的以太网类型/////change!!!!!!
        }
        actions = {
            set_swid_out();
            NoAction;
        }
        default_action = NoAction();
    }
    apply {    
        if(hdr.ipv4.isValid()&&hdr.srv6h.isValid()){
            if(hdr.srv6h.last_entry==hdr.srv6h.segment_left+1){
              /*   bit<32> packet_length;
                bit<32> new_packet_length;
                bit<32> packet_count;
                bit<32> new_packet_count; */
                if(hdr.srv6h.last_entry==3){
                    which_array_to_fill_for_four_list_out_normal.apply();
                }else if(hdr.srv6h.last_entry==4){
                    which_array_to_fill_for_five_list_out_normal.apply();
                }else if(hdr.srv6h.last_entry==2){
                    which_array_to_fill_for_three_list_out_normal.apply();
                }
                /* byte_cnt_reg.read(packet_length,meta.index);
                new_packet_length=packet_length+standard_metadata.packet_length;
                byte_cnt_reg.write(meta.index,new_packet_length);

                packet_cnt_reg.read(packet_count,meta.index);
                new_packet_count=packet_count+1;
                packet_cnt_reg.write(meta.index,new_packet_count); */
                byte_cnt_reg_accumulate_out.execute(meta.index);
                packet_cnt_reg_accumulate_out.execute(meta.index);
            }
        }else if(hdr.probe_header.isValid()){
                if(hdr.srv6h.last_entry==6||hdr.srv6h.last_entry==8){
                    if((hdr.srv6h.last_entry==6&&hdr.srv6h.segment_left==5) ||(hdr.srv6h.last_entry==6&&hdr.srv6h.segment_left==2) ){
                        both_direction_for_INT_six_list_egress.apply();
                    }else if((hdr.srv6h.last_entry==8&&hdr.srv6h.segment_left==7) ||(hdr.srv6h.last_entry==8&&hdr.srv6h.segment_left==3)){
                        both_direction_for_INT_eight_list_egress.apply();
                    }
                    if((hdr.srv6h.last_entry==6&&hdr.srv6h.segment_left!=0)||(hdr.srv6h.last_entry==8&&hdr.srv6h.segment_left!=0)){
                        hdr.probe_data.push_front(1);
                        hdr.probe_data[0].setValid(); 
                        swid_out_both.apply();
                        hdr.probe_header.num_probe_data=hdr.probe_header.num_probe_data+1;
                        /* bit<32> packet_length;
                        bit<32> packet_count;
                        bit<48> last_time;
                        bit<48> cur_time; */
                        /* cur_time=standard_metadata.ingress_global_timestamp;
                        last_time_reg.read(last_time,meta.index);
                        hdr.probe_data[0].cur_time=cur_time;
                        hdr.probe_data[0].last_time=last_time;
                        last_time_reg.write(meta.index,cur_time);

                        packet_cnt_reg.read(packet_count,meta.index);
                        hdr.probe_data[0].packet_cnt=packet_count;
                        packet_cnt_reg.write(meta.index,0);

                        byte_cnt_reg.read(packet_length,meta.index);
                        hdr.probe_data[0].byte_cnt=packet_length;
                        byte_cnt_reg.write(meta.index,0);   */
                        hdr.probe_data[0].cur_time=eg_intr_prsr_md.global_tstamp;
                        hdr.probe_data[0].last_time=last_time_reg_read_out.execute(meta.index);
                        last_time_reg_update_out.execute(meta.index);

                        hdr.probe_data[0].packet_cnt=packet_cnt_reg_read_out.execute(meta.index);
                        
                        hdr.probe_data[0].byte_cnt=byte_cnt_reg_read_out.execute(meta.index);
                        }
                }else if(hdr.srv6h.last_entry==3 || hdr.srv6h.last_entry==4|| hdr.srv6h.last_entry==2){   //说明这是一个单向INT包
                if(hdr.srv6h.last_entry==3 && hdr.srv6h.segment_left==2){
                    which_array_to_fill_for_four_list_out_INT.apply();
                }else if(hdr.srv6h.last_entry==4 && hdr.srv6h.segment_left==3){
                    which_array_to_fill_for_five_list_out_INT.apply();
                }else if(hdr.srv6h.last_entry==2 && hdr.srv6h.segment_left==1){
                    which_array_to_fill_for_three_list_out_INT.apply();
                }
                if((hdr.srv6h.last_entry==3&&hdr.srv6h.segment_left!=0)||(hdr.srv6h.last_entry==4&&hdr.srv6h.segment_left!=0)||(hdr.srv6h.last_entry==2&&hdr.srv6h.segment_left!=0)){
                    hdr.probe_data.push_front(1);
                    hdr.probe_data[0].setValid(); 
                    swid_out_single.apply();
                    hdr.probe_header.num_probe_data=hdr.probe_header.num_probe_data+1;
                   /*  bit<32> packet_length;
                    bit<32> packet_count;
                    bit<48> last_time;
                    bit<48> cur_time;
                    cur_time=standard_metadata.ingress_global_timestamp;
                    last_time_reg.read(last_time,meta.index);
                    hdr.probe_data[0].cur_time=cur_time;
                    hdr.probe_data[0].last_time=last_time;
                    last_time_reg.write(meta.index,cur_time);

                    packet_cnt_reg.read(packet_count,meta.index);
                    hdr.probe_data[0].packet_cnt=packet_count;
                    packet_cnt_reg.write(meta.index,0);

                    byte_cnt_reg.read(packet_length,meta.index);
                    hdr.probe_data[0].byte_cnt=packet_length;
                    byte_cnt_reg.write(meta.index,0);   */
                    hdr.probe_data[0].cur_time=eg_intr_prsr_md.global_tstamp;
                    hdr.probe_data[0].last_time=last_time_reg_read_out.execute(meta.index);
                    last_time_reg_update_out.execute(meta.index);

                    hdr.probe_data[0].packet_cnt=packet_cnt_reg_read_out.execute(meta.index);
                    
                    hdr.probe_data[0].byte_cnt=byte_cnt_reg_read_out.execute(meta.index);
                    }
                }
                
        }
        
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
