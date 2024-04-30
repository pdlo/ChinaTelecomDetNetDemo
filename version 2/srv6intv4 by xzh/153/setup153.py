
p4 = bfrt.srv6int_v4.pipe

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

#intipv6转发
ipv6_lpm_int = p4.Ingress.ipv6_lpm_int
ipv6_lpm_int.add_with_ipv6_forward(dst_ipv6=0x00000152000000000000000000000000, src_mac=0x000000000153, dst_mac=0x000000152000, port=128)
ipv6_lpm_int.add_with_ipv6_forward(dst_ipv6=0x00000154000000000000000000000000, src_mac=0x000000000153, dst_mac=0x000000154000, port=168)
ipv6_lpm_int.add_with_ipv6_forward(dst_ipv6=0x00000159000000000000000000000000, src_mac=0x000000000153, dst_mac=0x000000159000, port=184)
ipv6_lpm_int.add_with_ipv6_forward(dst_ipv6=0x00000188000000000000000000000000, src_mac=0x0a0a0a0a0a0a, dst_mac=0x208810c2555f, port=152)

#ipv4转发
ipv4_lpm = p4.Ingress.ipv4_lpm
ipv4_lpm.add_with_ipv4_forward(dst_ipv4=0x14140102, src_mac=0x0a0a0a0a0a0a, dst_mac=0x208810c2555f, port=152)

#流量等级映射
select_traffic_class = p4.Ingress.select_traffic_class
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7777, trafficclass=0x01)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7779, trafficclass=0x01)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=6789, trafficclass=0x01)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7780, trafficclass=0x01)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7781, trafficclass=0x01)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=10035, trafficclass=0x02)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=10054, trafficclass=0x02)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=10086, trafficclass=0x02)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=80, trafficclass=0x02)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7782, trafficclass=0x03)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7783, trafficclass=0x03)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7784, trafficclass=0x03)
select_traffic_class.add_with_get_traffic_class(dst_ipv4=0x140a0102, src_ipv4=0x14140102, dst_port=7785, trafficclass=0x03)

#srv6处理,插入ipv6
select_srv6_path_1 = p4.Ingress.select_srv6_path_1
select_srv6_path_1.add_with_ipv6_insert(dst_ipv4=0x140a0102, trafficclass=0x00, src_ipv6=0x00000153000000000000000000000000, dst_ipv6=0x00000152000000000000000000000000)
select_srv6_path_1.add_with_ipv6_insert(dst_ipv4=0x140a0102, trafficclass=0x01, src_ipv6=0x00000153000000000000000000000000, dst_ipv6=0x00000152000000000000000000000000)
select_srv6_path_1.add_with_ipv6_insert(dst_ipv4=0x140a0102, trafficclass=0x02, src_ipv6=0x00000153000000000000000000000000, dst_ipv6=0x00000152000000000000000000000000)
select_srv6_path_1.add_with_ipv6_insert(dst_ipv4=0x140a0102, trafficclass=0x03, src_ipv6=0x00000153000000000000000000000000, dst_ipv6=0x00000152000000000000000000000000)

#srv6处理,插入srv6
select_srv6_path_2 = p4.Ingress.select_srv6_path_2
select_srv6_path_2.add_with_srv6_insert(dst_ipv4=0x140a0102, trafficclass=0x00, num_segments=0x01, last_entry=0x01, 
s1=0x00000151000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000000000000000000000000000000, 
s4=0x00000000000000000000000000000000, 
s5=0x00000000000000000000000000000000)
select_srv6_path_2.add_with_srv6_insert(dst_ipv4=0x140a0102, trafficclass=0x01, num_segments=0x01, last_entry=0x01, 
s1=0x00000151000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000000000000000000000000000000, 
s4=0x00000000000000000000000000000000, 
s5=0x00000000000000000000000000000000)
select_srv6_path_2.add_with_srv6_insert(dst_ipv4=0x140a0102, trafficclass=0x02, num_segments=0x01, last_entry=0x01, 
s1=0x00000151000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000000000000000000000000000000, 
s4=0x00000000000000000000000000000000, 
s5=0x00000000000000000000000000000000)
select_srv6_path_2.add_with_srv6_insert(dst_ipv4=0x140a0102, trafficclass=0x03, num_segments=0x01, last_entry=0x01, 
s1=0x00000151000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000000000000000000000000000000, 
s4=0x00000000000000000000000000000000, 
s5=0x00000000000000000000000000000000)

#ipv6转发
ipv6_lpm = p4.Ingress.ipv6_lpm
ipv6_lpm.add_with_ipv6_forward(dst_ipv6=0x00000152000000000000000000000000, src_mac=0x000000000153, dst_mac=0x000000152000, port=128)
ipv6_lpm.add_with_ipv6_forward(dst_ipv6=0x00000154000000000000000000000000, src_mac=0x000000000153, dst_mac=0x000000154000, port=168)
ipv6_lpm.add_with_ipv6_forward(dst_ipv6=0x00000159000000000000000000000000, src_mac=0x000000000153, dst_mac=0x000000159000, port=184)
ipv6_lpm.add_with_ipv6_forward(dst_ipv6=0x00000188000000000000000000000000, src_mac=0x0a0a0a0a0a0a, dst_mac=0x208810c2555f, port=152)

bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("Table ipv6_lpm_int:")
ipv6_lpm_int.dump(table=True)
print ("Table ipv4_lpm:")
ipv4_lpm.dump(table=True)
print ("Table select_traffic_class:")
select_traffic_class.dump(table=True)
print ("Table select_srv6_path_1:")
select_srv6_path_1.dump(table=True)
print ("Table select_srv6_path_2:")
select_srv6_path_2.dump(table=True)
print ("Table ipv6_lpm:")
ipv6_lpm.dump(table=True)
                       
