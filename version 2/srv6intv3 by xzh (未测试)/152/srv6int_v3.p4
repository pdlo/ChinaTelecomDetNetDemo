
#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
#define MAX_HOPS 5

const bit<16> ETH_TYPE_IPV6 = 0x86dd;
const bit<8>  IPv6_NEXTHEADER_SRV6 = 43;
const bit<8>  IPv6_NEXTHEADER_CAL = 150;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

header ethernet_t {
    bit<48> dst_mac;
    bit<48> src_mac;
    bit<16> ether_type;
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

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/
struct my_ingress_headers_t {
    ethernet_t               ethernet;
    ipv6_h                   ipv6;
    srv6h_t                  srv6h;
    srv6_list_t[MAX_HOPS]    srv6_list;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct ingress_metadata_t {
}

    /***********************  P A R S E R  **************************/

parser IngressParser(packet_in pkt,
        /* User */    
        out my_ingress_headers_t hdr,
        out ingress_metadata_t meta,
        /* Intrinsic */
        out ingress_intrinsic_metadata_t ig_intr_md){
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETH_TYPE_IPV6: parse_ipv6;
            default: accept;
        }
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_hdr){
            IPv6_NEXTHEADER_SRV6: parse_srv6;
            IPv6_NEXTHEADER_CAL: parse_cal;
            default: accept;
        }    
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
        transition accept;
    }
    
    state parse_srv6_list_2 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition accept;
    }

    state parse_srv6_list_3 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition accept;
    }

    state parse_srv6_list_4 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition accept;
    }
    
    state parse_srv6_list_5 {
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        pkt.extract(hdr.srv6_list.next);
        transition accept;
    }

    state parse_cal {
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
        if (hdr.ipv6.isValid()) {
            // for ipv6
            if (hdr.srv6h.isValid()) {
                // for ipv6+srv6
                hdr.srv6h.segment_left = hdr.srv6h.segment_left - 1;
                if (hdr.srv6h.segment_left == 0) {
                    hdr.ipv6.dst_ipv6 = hdr.srv6_list[0].segment_id;
                }
                else if (hdr.srv6h.segment_left == 1) {
                    hdr.ipv6.dst_ipv6 = hdr.srv6_list[1].segment_id;
                }
                else if (hdr.srv6h.segment_left == 2) {
                    hdr.ipv6.dst_ipv6 = hdr.srv6_list[2].segment_id;
                }
                else if (hdr.srv6h.segment_left == 3) {
                    hdr.ipv6.dst_ipv6 = hdr.srv6_list[3].segment_id;
                }
                else if (hdr.srv6h.segment_left == 4) {
                    hdr.ipv6.dst_ipv6 = hdr.srv6_list[4].segment_id;
                }
                ipv6_lpm.apply();
            }
            else {
                // for ipv6+cal
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
        pkt.emit(hdr.ipv6);
        pkt.emit(hdr.srv6h);
        pkt.emit(hdr.srv6_list);
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