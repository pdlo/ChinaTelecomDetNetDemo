#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/

const bit<16> TYPE_IPV4 = 0x0800;
const bit<16> TYPE_IPV6 = 0x86dd;
const bit<16> TYPE_ARP = 0x0806;
const bit<48> VIRTUAL_MAC = 0x0a0a0a0a0a0a;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

header ethernet_t {
    bit<48> dst_mac;
    bit<48> src_mac;
    bit<16> ether_type;
}

header arp_t {
    bit<16>  hardware_type;
    bit<16>  protocol_type;
    bit<8>    HLEN;
    bit<8>    PLEN;
    bit<16>  OPER;
    bit<48>  sender_ha;
    bit<32>  sender_ip;
    bit<48>  target_ha;
    bit<32>  target_ip;
}

header ipv4_t {
    bit<4>     version;
    bit<4>     ihl;
    bit<8>     diffserv;
    bit<16>    total_len;
    bit<16>    identification;
    bit<3>      flags;
    bit<13>    frag_offset;
    bit<8>      ttl;
    bit<8>      protocol;
    bit<16>    hdr_checksum;
    bit<32>    src_addr;
    bit<32>    dst_addr;
}

header ipv6_t {
    bit<4>     version;
    bit<8>     traffic_class;
    bit<20>   flow_label;
    bit<16>   payload_len;
    bit<8>     next_header;
    bit<8>     hop_limit;
    bit<128>  src_addr;
    bit<128>  dst_addr;
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    ethernet_t       ethernet;
    arp_t                arp;
    ipv6_t               ipv6;
    ipv4_t               ipv4;
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct ingress_metadata_t {
}

    /***********************  P A R S E R  **************************/

parser IngressParser(packet_in packet,
        /* User */    
        out my_ingress_headers_t hdr,
        out ingress_metadata_t meta,
        /* Intrinsic */
        out ingress_intrinsic_metadata_t ig_intr_md)
{
     state start {
        packet.extract(ig_intr_md);
        packet.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            TYPE_ARP: parse_arp;
            TYPE_IPV6: parse_ipv6;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_arp {
        packet.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition select(hdr.ipv6.next_header) {
            0x04: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
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
//*************************************************************
    action ipv6_forward(bit<48> src_mac, bit<48> dst_mac, PortId_t port) {
        hdr.ethernet.src_mac = src_mac;
        hdr.ethernet.dst_mac = dst_mac;
        ig_intr_tm_md.ucast_egress_port = port;
    }
    table mapping_ipv6 {
        key = {
            hdr.ipv6.dst_addr: exact;
        }
        actions = {
            ipv6_forward;
            drop;
        }
        size = 1024;
        const default_action = drop();
    }
//********************************************************
    action ipv4_forward(bit<48> src_mac, bit<48> dst_mac, PortId_t port) {
        hdr.ethernet.src_mac = src_mac;
        hdr.ethernet.dst_mac = dst_mac;
        ig_intr_tm_md.ucast_egress_port = port;
    }
    table mapping_ipv4 {
        key = {
            hdr.ipv4.dst_addr: exact;
        }
        actions = {
            ipv4_forward;
            drop;
        }
        size = 1024;
        const default_action = drop();
    }
//******************************************************
    apply {
        if (hdr.arp.isValid()) {
            //deal with arp packet
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
        else {
            if (hdr.ipv6.isValid()) {
                //deal with ipv6 packet
                mapping_ipv6.apply();
            }
            else if (hdr.ipv4.isValid()) {
                //deal with ipv4 packet
                mapping_ipv4.apply();
            }
        }
    }
}

    /*********************  D E P A R S E R  ************************/

control IngressDeparser(packet_out packet,
        /* User */
        inout my_ingress_headers_t hdr,
        in ingress_metadata_t meta,
        /* Intrinsic */
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.arp);
        packet.emit(hdr.ipv6);
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