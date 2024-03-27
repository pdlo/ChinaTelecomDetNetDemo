#!/usr/bin/env python3
import sys
from datetime import datetime
from scapy.all import sniff, get_if_list
from sqlmodel import SQLModel, Session, select, create_engine
from src.int.headers_definition import probe_data
from src.orm import SgwLink,SgwLinkState,get_engine
from sqlmodel import select as sql_select

# 创建数据库引擎，这里的 DATABASE_URI 应该替换为实际的数据库 URI
#DATABASE_URI = 'sqlite:///database.db'
#engine = create_engine(DATABASE_URI)

# 请确保在启动脚本之前数据库模型已经创建
#SQLModel.metadata.create_all(engine)

def get_if():
    ifs = get_if_list()
    iface = None
    for i in ifs:
        if "eth1" in i:
            iface = i
            break
    if not iface:
        print("Cannot find eth0 interface")
        exit(1)
    return iface

def expand(x):
    yield x
    while x.payload:
        x = x.payload
        yield x

def handle_pkt(pkt):
    if pkt.haslayer(probe_data):
        probe_data_layers = [l for l in expand(pkt) if l.name == 'probe_data']
        print("")
        with Session(get_engine()) as session:
            l = len(probe_data_layers)
            for i in range(l - 1, -1, -1):
                Throughput = 1.0 * probe_data_layers[i].egress_byte_cnt / (probe_data_layers[i].egress_cur_time - probe_data_layers[i].egress_last_time)
                delay = (probe_data_layers[i].egress_cur_time - probe_data_layers[i - 1].egress_cur_time) * 10 ** -6
                delay = abs(delay)
                Packet_Loss_Rate = 1.0 * (probe_data_layers[i].egress_packet_count - probe_data_layers[i - 1].egress_packet_count) / probe_data_layers[i].egress_packet_count * 100
                print("Switch{} Port{} Switch{} Port{}    Throughput:{}MBps delay:{}s Packet_Loss_Rate:{}%".format(
                    probe_data_layers[i].swid, probe_data_layers[i].egress_port,
                    probe_data_layers[i - 1].swid, probe_data_layers[i - 1].egress_port,
                    Throughput, delay, Packet_Loss_Rate))

                swid_1 = probe_data_layers[i].swid
                egress_port_1 = probe_data_layers[i].egress_port
                swid_2 = probe_data_layers[i - 1].swid
                egress_port_2 = probe_data_layers[i - 1].egress_port

                statement = sql_select(SgwLink).where(
                    (SgwLink.src_sgw_id == swid_1) &
                    (SgwLink.src_bmv2_port == egress_port_1) &
                    (SgwLink.dst_sgw_id == swid_2) &
                    (SgwLink.dst_bmv2_port == egress_port_2)
                )
                sgw_link = session.exec(statement).first()
                if sgw_link and sgw_link.id:#避免静态类型检查器报错
                    link_state = SgwLinkState(
                        link_id=sgw_link.id,
                        create_datetime=datetime.now(),
                        delay=int(delay*100000),
                        rate=int(Throughput*100000),
                        lost=float(Packet_Loss_Rate)
                    )
                    session.add(link_state)
                    session.commit()

def main():
    iface = get_if()
    if iface:
        print(f"sniffing on {iface}")
        sys.stdout.flush()
        sniff(iface=iface, prn=lambda x: handle_pkt(x))
    else:
        print("No suitable interface found.")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("Stopping...")

if __name__!="__main__":
    raise Exception("试图import此代码")
