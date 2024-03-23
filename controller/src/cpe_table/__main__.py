"""
下发初始化流表
未测试
"""

from src.orm import engine,Host,Cpe,Route

from src import cpe_table

from sqlmodel import select,Session

session=Session(engine)


#对于每个主机，为相应的cpe下发srv6_drop
hosts=session.exec(select(Host)).all()
for i in hosts:
    assert isinstance(i.cpe, Cpe)
    cpe_table.srv6_drop.add_with_ipv4_forward(
        i.cpe,
        dst_ip=i.ip,
        dst_mask=32,
        dst_mac=i.mac,
        bmv2_port=i.cpe_bmv2_port)

#对于route表的每一行，下发select_srv6_path_without_qos
routes = hosts=session.exec(select(Route)).all()
for i in routes:
    src_cpe = session.exec(select(Cpe).where(Cpe.id==i.src_cpe_id)).one()
    dst_cpe = session.exec(select(Cpe).where(Cpe.id==i.dst_cpe_id)).one()
    cpe_table.select_srv6_path_without_qos.add_with_srv6_insert(
        src_cpe,
        dst_ip=dst_cpe.subnet_ip,
        dst_mask=dst_cpe.subnet_mask,
        route_str=i.route
    )

session.close()
