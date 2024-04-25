p4 = bfrt.int_edge.pipe

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

#156对应的表
##流等级  table_add select_traffic_class get_traffic_class 10.0.4.4 10.0.1.3 100 => 2
#获取流等级表
select_traffic_class = p4.Ingress.select_traffic_class

#插入表项（目的端口与流等级匹配）
select_traffic_class.add_with_get_traffic_class(dst_addr=0x159ebc01, src_addr = 0x159cb601, dst_port=80, trafficclass = 2);


#srv6选路  table_add select_srv6_path srv6_insert 10.0.4.4/32 2 => 5 4 ::99 ::102 ::107 ::104 ::108 
#获取srv6选路表
select_srv6_path = p4.Ingress.select_srv6_path
#插入路径
select_srv6_path.add_with_srv6_insert(dst_addr="21.158.188.2", trafficclass = 2, num_segments= 3, last_entry=2,
s1 = 0x00000156000000000000000000000000,
s2 = 0x00000157000000000000000000000000, 
s3 = 0x00000158000000000000000000000000,
s4 = 0x00000000000000000000000000000000, 
s5 = 0x00000000000000000000000000000000);
#方向一从182--> 188
#ipv6转发  table_add ipv6_lpm_normal_start ipv6_forward ::158/128 => 00:00:0a:00:01:01 3
#获取ipv6表
ipv6_lpm_normal_start = p4.Ingress.ipv6_lpm_normal_start
#插入表项
ipv6_lpm_normal_start.add_with_ipv6_forward(dst_addr = 0x00000156000000000000000000000000, dstmacaddr= 0x6cec5a3b963d, port = 136);

#方向二从188--> 182
#获取ipv6表
ipv6_lpm_normal_end = p4.Ingress.ipv6_lpm_normal_end
#插入表项
ipv6_lpm_normal_end.add_with_ipv6_forward(dst_addr = 0x00000256000000000000000000000000, dstmacaddr= 0x6cec5a3b963e, port = 152);




bfrt.complete_operations()

print("""******************* PROGAMMING RESULTS *****************""")
print ("Table select_srv6_path:")
select_srv6_path.dump(table=True)

print ("Table select_traffic_class:")
select_traffic_class.dump(table=True)

print("Table ipv6_lpm_normal_start:")
ipv6_lpm_normal_start.dump(table=True)

print("Table ipv6_lpm_normal_end")
ipv6_lpm_normal_end.dump(table=True)

                       
