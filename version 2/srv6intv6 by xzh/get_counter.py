
p4 = bfrt.srv6int_v6.pipe

ingress_counter = p4.Ingress.ingress_counter
ingress_counter.operation_counter_sync()
ingress_counter_1 = ingress_counter.get(1)
ingress_counter_1_bytes = ingress_counter_1.data[b'$COUNTER_SPEC_BYTES']
ingress_counter_1_count = ingress_counter_1.data[b'$COUNTER_SPEC_PKTS']
print('bytes:', ingress_counter_1_bytes)
print('count:', ingress_counter_1_count)

bfrt.complete_operations()

'''
export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
$SDE_INSTALL/bin/bf_kdrv_mod_load $SDE_INSTALL
/root/bf-sde-9.1.0/run_bfshell.sh -b /root/my_p4/xzh/srv6int_v6/get_counter.py
'''