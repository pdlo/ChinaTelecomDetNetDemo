"""
下发初始化流表
未测试
"""

from src.orm import get_engine,Host,Cpe,Route
from src import cpe_table
from src.cpe_table.send_bfrt_python import send

from collections import defaultdict
from sqlmodel import select,Session
from pathlib import Path

log_path=Path(__file__).parent.parent.parent/'logs'

codes=defaultdict(list)
stdouts=defaultdict(list)
def send_code_with_log(cpe:Cpe,code:str):
    codes[cpe.name].append(code)
    stdout=send(cpe,code)
    stdouts[cpe.name].append(stdout)
def save_log():
    for k,v in codes.items():
        with ( log_path/f'{k} 代码.py' ).open('w') as f:
            f.write("from typing import Any\nbfrt:Any\n"+"\n\n#====================================\n\n".join(v))
    for k,v in stdouts.items():
        with ( log_path/f'{k} 输出' ).open('w') as f:
            f.write("\n\n#====================================\n\n".join(v))

session=Session(get_engine())

# 对于每个主机，为相应的cpe下发srv6_drop
hosts=session.exec(select(Host)).all()
for i in hosts:
    print(f"\n\n下发{i.name} 流表\n")
    assert isinstance(i.cpe, Cpe)
    code = cpe_table.srv6_drop.add_with_ipv4_forward(
        i.cpe,
        dst_ip=i.ip,
        dst_mask=32,
        dst_mac=i.mac,
        bmv2_port=i.cpe_bmv2_port,
        send_code=False)
    send_code_with_log(i.cpe,code)

#对于route表的每一行，下发select_srv6_path
routes = hosts=session.exec(select(Route)).all()
for i in routes:
    print(f"\n\n下发{i.src_cpe.name} -> {i.dst_cpe.name}流表\n")
    src_cpe = session.exec(select(Cpe).where(Cpe.id==i.src_cpe_id)).one()
    dst_cpe = session.exec(select(Cpe).where(Cpe.id==i.dst_cpe_id)).one()
    code = cpe_table.select_srv6_path.add_with_srv6_insert(
        src_cpe,
        dst_ip=dst_cpe.subnet_ip,
        dst_mask=dst_cpe.subnet_mask,
        qos=i.qos,
        route_str=i.route,
        send_code=False
    )
    send_code_with_log(src_cpe,code)

session.close()

save_log()