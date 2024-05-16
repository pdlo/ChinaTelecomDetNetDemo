
import time

def empty_func(*args):
    pass

# ipv6_lpm = p4.Ingress.ipv6_lpm
# # ipv6_lpm.dump(table=True)
# ingress_counter = p4.Ingress.ingress_counter
# ingress_counter.operation_counter_sync(empty_func)
# # ingress_counter.operation_counter_sync()
# # ingress_counter.get(1)

# bfrt.complete_operations()

# ingress_counter.dump(table=True)
# # ingress_counter_1 = ingress_counter.get(1)
# # ingress_counter_1_bytes = ingress_counter_1.data[b'$COUNTER_SPEC_BYTES']
# # ingress_counter_1_count = ingress_counter_1.data[b'$COUNTER_SPEC_PKTS']
# # print('bytes:', ingress_counter_1_bytes)
# # print('count:', ingress_counter_1_count)

# while(1):
p4 = bfrt.srv6int_v6.pipe
ingress_counter = p4.Ingress.ingress_counter
ingress_counter.operation_counter_sync(empty_func)
ingress_counter.dump(table=True)


# p4 = bfrt.srv6int_v4.pipe
# register_packet_cnt = p4.Ingress.register_packet_cnt
# register_packet_cnt.operation_register_sync(empty_func)
# register_packet_cnt.dump(table=True)

bfrt.complete_operations()

    # time.sleep(1)

# ingress_counter.exit()


# export SDE=/root/bf-sde-9.1.0
# export SDE_INSTALL=$SDE/install
# export PATH=$SDE_INSTALL/bin:$PATH
# $SDE_INSTALL/bin/bf_kdrv_mod_load $SDE_INSTALL
# /root/bf-sde-9.1.0/run_bfshell.sh -b /root/my_p4/xzh/srv6int_v6/get_counter.py

