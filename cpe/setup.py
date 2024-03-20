
p4 = bfrt.srv6.pipe

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

#ipv4转发
#ipv4_lpm = p4.Ingress.ipv4_lpm
#srv6处理
insert_srv6 = p4.Ingress.insert_srv6
#srv6头部丢弃
#srv6_abandon = p4.Ingress.srv6_abandon

# 这里负责转发
# 将数据包从交换机端口140转发给10.153.182.2（mac地址为0xa0:36:9f:ed:55:62），端口172
#ipv4_lpm.add_with_ipv4_forward(dst_addr=0x0a99b602, dst_addr_p_length=32,src_mac=0x000000153182, dst_mac=0xa0369fed5562, port=172)
# 将数据包从交换机端口156转发给10.153.162.2（mac地址为0xe8:61:1f:37:b6:d3），端口156
#ipv4_lpm.add_with_ipv4_forward(dst_addr=0x0a99a202, dst_addr_p_length=32,src_mac=0x000000153162, dst_mac=0xe8611f37b6d3, port=156)

#srv6处理
#ipv4包插入
#insert_srv6.add_with_srv6_insert(ether_type=0x0800, num_segments=0x05, s1=0x0a080002111111112222222233333333, s2=0x0a080002111111112222222233333333, s3=0x0a080002111111112222222233333333, s4=0x0a080002111111112222222233333333, s5=0x0a080002111111112222222233333333)
insert_srv6.add_with_srv6_insert(dst_addr=0x0a99b602, dst_addr_p_length=32, num_segments=0x05 ,src_mac=0x000000153182, dst_mac=0xa0369fed5562, port=172, s1=0x1, s2=0x2, s3=0x3, s4=0x4, s5=0x5)
insert_srv6.add_with_srv6_insert(dst_addr=0x0a99a202, dst_addr_p_length=32, num_segments=0x05, src_mac=0x000000153162, dst_mac=0xe8611f37b6d3, port=156, s1=0x1, s2=0x2, s3=0x3, s4=0x4, s5=0x5)
#INT包插入
#insert_srv6.add_with_srv6_insert(ether_type=0x0812, num_segments=0x05, s1=0x000181, s2=0x000182, s3=0x000183, s4=0x000184, s5=0x000185)



bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("Table ipv4_lpm:")
#ipv4_lpm.dump(table=True)
print ("Table insert_srv6:")
insert_srv6.dump(table=True)
                       
