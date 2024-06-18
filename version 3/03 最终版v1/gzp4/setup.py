
p4 = bfrt.sinet_v1.pipe

# This function can clear all the tables and later on other fixed objects
# once bfrt support is added.
def clear_all(verbose=True, batching=True):
    global p4
    global bfrt
    
    def _clear(table, verbose=False, batching=False):
        if verbose:
            print("Clearing table {:<40} ... ".
                  format(table['full_name']), end='', flush=True)
        try:    
            entries = table['node'].get(regex=True, print_ents=False)
            try:
                if batching:
                    bfrt.batch_begin()
                for entry in entries:
                    entry.remove()
            except Exception as e:
                print("Problem clearing table {}: {}".format(
                    table['name'], e.sts))
            finally:
                if batching:
                    bfrt.batch_end()
        except Exception as e:
            if e.sts == 6:
                if verbose:
                    print('(Empty) ', end='')
        finally:
            if verbose:
                print('Done')

        # Optionally reset the default action, but not all tables
        # have that
        try:
            table['node'].reset_default()
        except:
            pass
    
    # The order is important. We do want to clear from the top, i.e.
    # delete objects that use other objects, e.g. table entries use
    # selector groups and selector groups use action profile members
    

    # Clear Match Tables
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR']:
            _clear(table, verbose=verbose, batching=batching)

    # Clear Selectors
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['SELECTOR']:
            _clear(table, verbose=verbose, batching=batching)
            
    # Clear Action Profiles
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['ACTION_PROFILE']:
            _clear(table, verbose=verbose, batching=batching)
    
clear_all()

mapping_ipv6 = p4.Ingress.mapping_ipv6
#172.29.89.113组播arp
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0xff0200000000000000000001ff000071, dscp=0, port=24)
#172.29.89.113
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0x24028800FFFE01130000000000000071, dscp=0, port=24)
#172.29.89.114组播arp
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0xff0200000000000000000001ff000072, dscp=0, port=56)
#172.29.89.114
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0x24028800FFFE01130000000000000072, dscp=0, port=56)
#172.29.89.126组播arp
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0xff0200000000000000000001ff000001, dscp=0, port=64)
#172.29.89.126
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0x24028800FFFE01130000000000000001, dscp=0, port=64)
#172.27.15.130
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0x24028800FFFE010E0000000010600082, dscp=0, port=64)
#172.27.15.131
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0x24028800FFFE010E0000000010600083, dscp=0, port=64)
#172.27.15.132
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0x24028800FFFE010E0000000010600084, dscp=0, port=64)
#172.27.15.129
mapping_ipv6.add_with_ipv6_forward(dst_ipv6=0x24028800FFFE010E0000000010600001, dscp=0, port=64)

mapping_ipv4 = p4.Ingress.mapping_ipv4
#172.29.89.113
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1d5971, port=24)
#172.29.89.114
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1d5972, port=56)
#172.29.89.115
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1d5973, port=132)
#172.29.89.116
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1d5974, port=65)
#172.29.89.126
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1d597e, port=64)

#172.27.15.130
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1b0f82, port=64)
#198.18.203.130
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xc612cb82, port=64)
#172.27.15.131
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1b0f83, port=64)
#198.18.203.131
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xc612cb83, port=64)
#172.27.15.129
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xac1b0f81, port=64)
#198.18.203.129
mapping_ipv4.add_with_ipv4_forward(dst_ipv4=0xc612cb81, port=64)

trafficclass_set = p4.Ingress.trafficclass_set
#172.29.89.113->172.29.89.114, 7777, 1
trafficclass_set.add_with_get_traffic_class(src_ipv4=0xac1d5971, dst_ipv4=0xac1d5972, dst_port=7777, trafficclass=1)
#172.29.89.114->172.29.89.113, 7777, 1
trafficclass_set.add_with_get_traffic_class(src_ipv4=0xac1d5972, dst_ipv4=0xac1d5971, dst_port=7777, trafficclass=1)


dscp_get = p4.Ingress.dscp_get
#172.29.89.114, 1, 1
dscp_get.add_with_set_dscp(dst_ipv4=0xac1d5972, trafficclass=1, dscp=1)
#172.29.89.113, 1, 1
dscp_get.add_with_set_dscp(dst_ipv4=0xac1d5971, trafficclass=1, dscp=1)


register_index_get_ingress = p4.Ingress.register_index_get_ingress
register_index_get_ingress.add_with_set_register_index_ingress(ingress_port=24, ingress_index=13)
register_index_get_ingress.add_with_set_register_index_ingress(ingress_port=56, ingress_index=9)
register_index_get_ingress.add_with_set_register_index_ingress(ingress_port=64, ingress_index=33)
register_index_get_ingress.add_with_set_register_index_ingress(ingress_port=65, ingress_index=34)
register_index_get_ingress.add_with_set_register_index_ingress(ingress_port=132, ingress_index=1)

register_index_get_egress = p4.Ingress.register_index_get_egress
register_index_get_egress.add_with_set_register_index_egress(ucast_egress_port=24, egress_index=13)
register_index_get_egress.add_with_set_register_index_egress(ucast_egress_port=56, egress_index=9)
register_index_get_egress.add_with_set_register_index_egress(ucast_egress_port=64, egress_index=33)
register_index_get_egress.add_with_set_register_index_egress(ucast_egress_port=65, egress_index=34)
register_index_get_egress.add_with_set_register_index_egress(ucast_egress_port=132, egress_index=1)

bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("Table mapping_ipv6:")
mapping_ipv6.dump(table=True)
print ("Table mapping_ipv4:")
mapping_ipv4.dump(table=True)
print ("Table trafficclass_set:")
trafficclass_set.dump(table=True)
print ("Table dscp_get:")
dscp_get.dump(table=True)
print ("Table register_index_get_ingress:")
register_index_get_ingress.dump(table=True)
print ("Table register_index_get_egress:")
register_index_get_egress.dump(table=True)