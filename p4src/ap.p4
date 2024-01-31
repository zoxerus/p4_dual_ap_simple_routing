/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define PKT_INSTANCE_TYPE_NORMAL 0
#define PKT_INSTANCE_TYPE_INGRESS_CLONE 1
#define PKT_INSTANCE_TYPE_EGRESS_CLONE 2

const bit<8>  UDP_PROTOCOL = 0x11;
const bit<16> TYPE_IPV4 = 0X800;
// const bit<6> TYPE_INT = 6w31;
// const bit<16> TYPE_INT1 = 0x10E2;
const bit<32> REPORT_MIRROR_SESSION_ID = 500;
const bit<6> IPv4_DSCP_INT = 6w31;   // indicates an INT header in the packet
const bit<16> INT_SHIM_HEADER_LEN_BYTES = 4;
const bit<8> INT_TYPE_HOP_BY_HOP = 1;
//const bit<16> HOP_MD_LEN_BYTES = 36;
const bit<16> HOP_MD_LEN_BYTES = 40;
//const bit<5> HOP_MD_WORDS = 9;
const bit<5> HOP_MD_WORDS = 10;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

typedef bit<16> switchID_t;
typedef bit<48> ingress_t;
typedef bit<48> egress_t;
typedef bit<32> hoplatency_t;
typedef bit<16> flow_id_t;
typedef bit<16> cpu_t;
typedef bit<32> geo_lalitude_t;
typedef bit<32> geo_longitude_t;
typedef bit<32> geo_altitude_t;
typedef bit<32> antenna_power_t;
//typedef bit<24> padding_field_t;

header ethernet_t {
    macAddr_t dstMac;
    macAddr_t srcMac;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<6>    dscp;
    bit<2>    ecn;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcIP;
    ip4Addr_t dstIP;
}

header udp_t {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> length_;
    bit<16> checksum;
}

header switch_int_t {
    switchID_t       swid;            // 16 bit
    cpu_t            cpu_value;       // 16 bits
    geo_lalitude_t   geo_lalitude;    // 32 bits
    geo_longitude_t  geo_longitude;   // 32 bits
    geo_altitude_t   geo_altitude;    // 32 bits
    antenna_power_t  antenna_power;   // 32 bits

}

struct metadata {
    //empty
}

struct headers {
    ethernet_t         ethernet;
    ipv4_t             ipv4;
    // int_header_t       int_header;
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
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
        // transition select(hdr.ipv4.protocol) {
        //     UDP_PROTOCOL     : parse_udp;
        //     default          : accept;
        // }
    }

}


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
     
    // counter(32w1, CounterType.packets) fwd_counter;

    action drop() {
        mark_to_drop(standard_metadata);
        exit;
    }


    //-------------------------------------------------------------//
    //--------- M U L T I C A S T  H A N D L I N G ----------------//

    action ac_set_mcast_grp (bit<16> mcast_grp) {

        standard_metadata.mcast_grp = mcast_grp;
        // See Section 6.4 of RFC 1112
        hdr.ethernet.dstMac = 0xffffffffffff;

        // The P4_16 |-| operator is a saturating operation, meaning
        // that since the operands are unsigned integers, the result
        // cannot wrap around below 0 back to the maximum possible
        // value, the way the result of the - operator can.
        hdr.ipv4.ttl = hdr.ipv4.ttl |-| 1;
    } 

    table tb_ipv4_mc_route_lookup {
        key = {
            hdr.ipv4.dstIP: lpm;
        }
        actions = {
            ac_set_mcast_grp;
            drop;
        }
        const default_action = drop;
    }


    //------------------------------------------------------//
    //------------  I P V 4  H A N D L I N G   -------------//

    action ac_ipv4_forward(egressSpec_t port, macAddr_t dMac) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcMac = hdr.ethernet.dstMac;
        hdr.ethernet.dstMac = dMac;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;

    }

    table tb_ipv4_lpm {
        key = {            
            hdr.ipv4.dstIP: lpm;
            // hdr.udp.dst_port: ternary;
        }
        actions = {
            ac_ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    //------------------------------------------------------//
    //---------------  L 2  H A N D L I N G  ---------------//

    action ac_l2_forward(egressSpec_t eif ){
        standard_metadata.egress_spec = eif;
    }

    action ac_l2_broadcast(bit<16> mcast_grp ){
        standard_metadata.mcast_grp = mcast_grp;

    }

    table tb_l2_forward {
        key = {
            hdr.ethernet.dstMac             :   exact;
        } 
        actions = {
            ac_l2_forward;
            ac_l2_broadcast;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }   
    
    //------------------------------------------------------//
    //------ I N G R E S S  P R O C E S S I N G ------------//

    apply {

        if (hdr.ipv4.isValid()) {
            if( !tb_ipv4_lpm.apply().hit){
                tb_ipv4_mc_route_lookup.apply();
            }
        } else {
            tb_l2_forward.apply();
        }


    } // END OF APPLY BLOCK
    
} // END OF INGRESS BLOCK


/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
        apply{
            log_msg("ingress_port: {}, egress_port: {}", {standard_metadata.ingress_port, standard_metadata.egress_port });

            if (standard_metadata.ingress_port == standard_metadata.egress_port) {
                mark_to_drop(standard_metadata);
            }

        }
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
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcIP,
              hdr.ipv4.dstIP },
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
        packet.emit(hdr.ipv4);
        // packet.emit(hdr.udp);
        // packet.emit(hdr.shim);
        // packet.emit(hdr.int_header);
        // packet.emit(hdr.sw_data);
        // packet.emit(hdr.sw_traces);
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
