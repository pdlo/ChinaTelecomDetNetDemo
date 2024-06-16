#include <core.p4>
#include <v1model.p4>
const bit<16> ETH_TYPE_IPV4 = 0x0800;
header ethernet_t {
    bit<48> dst_mac;
    bit<48> src_mac;
    bit<16> ether_type;
}
header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   total_len;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   frag_offset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdr_checksum;
    bit<32>   src_ipv4;
    bit<32>   dst_ipv4;
}
struct my_ingress_headers_t {
    ethernet_t               ethernet;
    ipv4_t                   ipv4;
}
struct ingress_metadata_t {
    
}

parser MyParser(packet_in pkt,
                out my_ingress_headers_t hdr,
                inout ingress_metadata_t meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETH_TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4{
        pkt.extract(hdr.ipv4);
        transition accept;
        }
}
control MyVerifyChecksum(inout my_ingress_headers_t hdr, inout ingress_metadata_t meta) {
    apply {  }
}   
control MyIngress(inout my_ingress_headers_t hdr,
                  inout ingress_metadata_t meta,
                  inout standard_metadata_t standard_metadata){
    action drop() {
        mark_to_drop(standard_metadata);
    }
    action ipv4_forward(bit<9> port) {
        standard_metadata.egress_spec = port;
    } 
    table mapping_ipv4 {
        key = {
            hdr.ipv4.dst_ipv4: exact;
        }
        actions = {
            ipv4_forward;
            drop;
        }
        size = 1024;
        const default_action = drop();
    }
    apply{
        mapping_ipv4.apply();
    }
}
control MyEgress(inout my_ingress_headers_t hdr,
                 inout ingress_metadata_t meta,
                 inout standard_metadata_t standard_metadata) {
        apply{
            
        }
}
control MyComputeChecksum(inout my_ingress_headers_t  hdr, inout ingress_metadata_t meta) {
    apply {
        update_checksum(
        hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.total_len,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.frag_offset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.src_ipv4,
              hdr.ipv4.dst_ipv4 },
            hdr.ipv4.hdr_checksum,
            HashAlgorithm.csum16);
        }
}
control MyDeparser(packet_out pkt, in my_ingress_headers_t hdr) {
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
    }
}
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;