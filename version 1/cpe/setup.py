
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

#srv6处理,插入路径
select_srv6_path = p4.Ingress.select_srv6_path
"""
key = {
           <32> hdr.ipv4.dst_addr: exact;   //目的ipv4
           <16> hdr.tcp.dst_port: exact;   //目的tcp端口
            <8> meta.trafficclass: exact;   //流等级       
        }
bit<8> num_segments, bit<8> last_entry,
        bit<48> src_mac, bit<48> dst_mac, bit<9> port, 
        bit<128> s1, bit<128> s2, bit<128> s3, bit<128> s4, bit<128> s5
"""

#srv6头部丢弃和ipv4转发
srv6_drop = p4.Ingress.srv6_drop
"""
key = {
         <31>   hdr.ipv4.dst_addr: lpm;
        }
bit<48> src_mac, bit<48> dst_mac, bit<9> port
"""

#获取流表
select_traffic_class = p4.Ingress.select_traffic_class
"""
key = {
          <32>  hdr.ipv4.dst_addr: exact;
          <32>  hdr.ipv4.src_addr: exact;
          <16>  hdr.tcp.dst_port: exact;
        }
bit<8> trafficclass
"""


#流等级
#10.153.162.2  0a99a202  
#10.152.166.2  0a98a602
#10.151.168.2  0a97a802
select_traffic_class.add_with_get_traffic_class(dst_addr="10.152.166.2", src_addr="10.153.162.2", dst_port=1234, trafficclass=0x01)
#10.153.162.2  10.151.168.2
#select_traffic_class.add_with_get_traffic_class(dst_addr=0x0a97a802, src_addr=0x0a99a202, dst_port=0x04d2, trafficclass=0x01)
#select_traffic_class.add_with_get_traffic_class(dst_addr=0x0a99a202, dst_addr_p_length=32, trafficclass=0x2)


#srv6处理
#10.152.166.2
"""
select_srv6_path.add_with_srv6_insert(dst_addr=0x0a98a602, num_segments=0x02, last_entry=0x01, src_mac=0x000015304156, dst_mac=0x000015204182, port=156, 
s1=0x00000187000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000152000000000000000000000000, 
s4=0x00000152000000000000000000000000, 
s5=0x00000183000000000000000000000000)


select_srv6_path.add_with_srv6_insert(dst_addr="10.152.166.2", trafficclass=0x01, num_segments=0x02, last_entry=0x01, src_mac=0x000015304156, dst_mac=0x000015204182, port=156, 
s1=0x00000187000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000187000000000000000000000000, 
s4=0x00000152000000000000000000000000, 
s5=0x00000183000000000000000000000000)

"""

select_srv6_path.add_with_srv6_insert(dst_addr="10.152.166.2", dst_addr_p_length=16, trafficclass=0x00, num_segments=0x04, last_entry=0x03, src_mac=0x000015304156, dst_mac=0x000015204182, port=156, 
s1=0x00000183000000000000000000000000, 
s2=0x00000185000000000000000000000000, 
s3=0x00000187000000000000000000000000, 
s4=0x00000152000000000000000000000000, 
s5=0x00000183000000000000000000000000)


select_srv6_path.add_with_srv6_insert(dst_addr="10.152.166.2",dst_addr_p_length=16 , trafficclass=0x01, num_segments=0x02, last_entry=0x01, src_mac=0x000015304156, dst_mac=0x000015204182, port=156, 
s1=0x00000187000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000187000000000000000000000000, 
s4=0x00000152000000000000000000000000, 
s5=0x00000183000000000000000000000000)


select_srv6_path.add_with_srv6_insert(dst_addr="10.151.168.2", trafficclass=0x01, num_segments=0x02, last_entry=0x01, src_mac=0x000015304156, dst_mac=0x000015204182, port=156, 
s1=0x00000187000000000000000000000000, 
s2=0x00000152000000000000000000000000, 
s3=0x00000187000000000000000000000000, 
s4=0x00000152000000000000000000000000, 
s5=0x00000183000000000000000000000000)


#10.151.168.2
#select_srv6_path.add_with_srv6_insert(dst_addr=0x0a99b802, dst_port=0x0002, trafficclass=0x01,num_segments=0x04, last_entry=0x03, src_mac=0x000015304156, dst_mac=0x000015204182, port=156, s1=0x1, s2=0x2, s3=0x3, s4=0x4, s5=0x5)

#srv6头部丢弃
srv6_drop.add_with_ipv4_forward(dst_addr="10.153.162.2", dst_addr_p_length=16, src_mac=0x000001533364, dst_mac=0xb8cef69c24be, port=64)
#srv6_drop.add_with_ipv4_forward(dst_addr=0x0a99b602, dst_addr_p_length=32, src_mac=0x000015204156, dst_mac=0xa0369fed5562, port=64)



bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("Table select_srv6_path:")
select_srv6_path.dump(table=True)
print ("Table srv6_drop:")
srv6_drop.dump(table=True)
print ("Table select_traffic_ckass:")
select_traffic_class.dump(table=True)
                       
