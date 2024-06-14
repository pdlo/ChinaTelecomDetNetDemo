
p4 = bfrt.simple_ipv6_v2.pipe

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
#172.27.15.130组播arp
mapping_ipv6.add_with_ipv6_forward(dst_addr=0xff0200000000000000000001ff600082, dscp=0, port=24)
#172.27.15.130
mapping_ipv6.add_with_ipv6_forward(dst_addr=0x24028800FFFE010E0000000010600082, dscp=0, port=24)
#172.27.15.131组播arp
mapping_ipv6.add_with_ipv6_forward(dst_addr=0xff0200000000000000000001ff600083, dscp=0, port=56)
#172.27.15.131
mapping_ipv6.add_with_ipv6_forward(dst_addr=0x24028800FFFE010E0000000010600083, dscp=0, port=56)
#172.27.15.129组播arp
mapping_ipv6.add_with_ipv6_forward(dst_addr=0xff0200000000000000000001ff600001, dscp=0, port=64)
#172.27.15.129
mapping_ipv6.add_with_ipv6_forward(dst_addr=0x24028800FFFE010E0000000010600001, dscp=0, port=64)
#172.29.89.113
mapping_ipv6.add_with_ipv6_forward(dst_addr=0x24028800FFFE01130000000000000071, dscp=0, port=64)
#172.29.89.114
mapping_ipv6.add_with_ipv6_forward(dst_addr=0x24028800FFFE01130000000000000072, dscp=0, port=64)
#172.29.89.118
mapping_ipv6.add_with_ipv6_forward(dst_addr=0x24028800FFFE01130000000000000001, dscp=0, port=64)

mapping_ipv4 = p4.Ingress.mapping_ipv4
#172.27.15.130
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xac1b0f82, dscp=0, port=24)
#172.27.15.131
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xac1b0f83, dscp=0, port=56)
#172.27.15.129
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xac1b0f81, dscp=0, port=64)

#172.29.89.113
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xac1d5971, dscp=0, port=64)
#198.18.204.113
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xc612cc71, dscp=0, port=64)
#172.29.89.114
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xac1d5972, dscp=0, port=64)
#198.18.204.114
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xc612cc72, dscp=0, port=64)
#172.29.89.126
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xac1d597e, dscp=0, port=64)
#198.18.204.126
mapping_ipv4.add_with_ipv4_forward(dst_addr=0xc612cc7e, dscp=0, port=64)

bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("Table mapping_ipv6:")
mapping_ipv6.dump(table=True)
print ("Table mapping_ipv4:")
mapping_ipv4.dump(table=True)

# #
# # Here goes mirroring stuff. REMEMBER: mirror sessions are programmed by
# # run_pd_rpc!
# #
# import os
# os.environ['SDE_INSTALL'] = os.path.split(os.environ['PATH'].split(":")[0])[0]
# os.environ['SDE']         = os.path.split(os.environ['SDE_INSTALL'])[0]

# def run_pd_rpc(cmd_or_code, no_print=False):
#     """
#     This function invokes run_pd_rpc.py tool. It has a single string argument
#     cmd_or_code that works as follows:
#        If it is a string:
#             * if the string starts with os.sep, then it is a filename
#             * otherwise it is a piece of code (passed via "--eval"
#        Else it is a list/tuple and it is passed "as-is"

#     Note: do not attempt to run the tool in the interactive mode!
#     """
#     import subprocess
#     path = os.path.join(os.environ['HOME'], "tools", "run_pd_rpc.py")
    
#     command = [path]
#     if isinstance(cmd_or_code, str):
#         if cmd_or_code.startswith(os.sep):
#             command.extend(["--no-wait", cmd_or_code])
#         else:
#             command.extend(["--no-wait", "--eval", cmd_or_code])
#     else:
#         command.extend(cmd_or_code)
        
#     result = subprocess.check_output(command).decode("utf-8")[:-1]
#     if not no_print:
#         print(result)
        
#     return result

# print("\nMirror Session Configuration:")
# run_pd_rpc("/root/chinatelecom/simple_ipv6/setup_mirror.py")