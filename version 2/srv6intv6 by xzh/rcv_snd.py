#!/usr/bin/env python3 
# coding=utf-8
# 在交换机运行此程序，收到终端的请求后就查询并返回dump结果
# 此python程序是p4自带的python3.4运行的
# 运行命令：bash /root/lt/run_read_reg.sh /root/lt/rcv_snd.py

import sys
# import socket 
from scapy.all import sniff 

p4 = bfrt.myp4_151.pipe
register_flow = p4.Ingress.register_flow
mapping_ipv4 = p4.Ingress.mapping_ipv4
dct_depart_to_port = {1:132, 5:164, 9:56, 13:24, 17:4, 21: 44, 25:176, 29:152, 32:128, 33:64}
iface = 'ma1'
count = 0

def CallBack(pkt):
    from scapy.all import sendp, get_if_hwaddr
    from scapy.all import Ether, IP, UDP
    import random
    import time
    from datetime import datetime
    global register_flow
    global mapping_ipv4
    global iface
    global count
    global dct_depart_to_port
    
    cmd_from_controller = pkt.payload.payload.load.decode().strip() # 得到raw数据
    if cmd_from_controller == "1":  # 用来查询寄存器
        # print(">>>>> ", "{}收到来自170的寄存器信息".format(datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')))
        def empty_func(*args):
            pass
        register_flow.operation_register_sync(empty_func)   # 传入的参数只是顶替了默认的打印函数
        # 提前执行，让它和dump之间有一些时间差，以免同步未完成
        
        src_mac = get_if_hwaddr(iface)
        src_ip = "192.168.199.151"
        ctlr_ip = "192.168.199.170"
        
        # dst_addr = socket.gethostbyname(ctlr_ip)
        pkt_send_back = Ether(src=src_mac, dst='e8:61:1f:37:b6:82')/IP(src=src_ip,dst=ctlr_ip)  /UDP(sport=60151,dport=60170)
        
        register_value = register_flow.dump(table=True, json=True) # table=True设置输出数据详细等级   。json为True就会有json格式的返回值
        # dump()函数签名在此目录下：~/bf-sde-9.1.0/install/lib/python3.4/bfrtcli.py 600多行
        bfrt.complete_operations() # 提交操作 

        pkt_send_back = pkt_send_back /register_value # 不用TCP了。
        sendp(pkt_send_back, iface=iface, verbose=False) # send 发IP包，sendp发mac包
        # print("<<<<< ", "{}发送给170寄存器信息".format(datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')))
    else:  # 用来修改流表
        # cmd_from_controller 的格式应为 目的主机编号，交换机出端口号，下一跳交换机编号。
        # pkt.show()
        cmd = cmd_from_controller.split(",")
        dst_host = cmd[0]
        depart = cmd[1]
        if len(depart) == 1:
            depart = "0" + depart   # 如果只有1位就在前面加一个0
        next_switch = cmd[2]
        dst_addr = int("0x0a000%s00" % dst_host, 16)
        src_mac = int("0x1510%s000000" % depart, 16)
        dst_mac = int("0x15%s0%s000000" % (next_switch, depart), 16)
        port = dct_depart_to_port[int(depart)]
        mapping_ipv4.mod_with_ipv4_forward(dst_addr=dst_addr, dst_addr_p_length=24, src_mac=src_mac, dst_mac=dst_mac, port=port)
    
# print("start sniffing ...")
pkt = sniff(iface=iface, store=0, prn=CallBack, filter="inbound and udp and src host 192.168.199.170 and dst host 192.168.199.151")
# 只收到UDP，因为ssh连接要发很多tcp ；但还是会收到很多莫名其妙的DNS包，所以源目的IP的判断还是不能少
# 一直监听，监听到就查表

