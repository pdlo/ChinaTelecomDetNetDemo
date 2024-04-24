from sqlmodel import select,Session
import sys
sys.path.append(r"D:\academic_work\ChinaTelecomDetNetDemo\controller")


from src.cpe_table import send_bfrt_python,select_srv6_path,select_traffic_class,srv6_drop,read_db
from src import orm

target_cpe=153
with Session(orm.get_engine()) as session:
    cpe=session.exec(select(orm.Cpe).where(orm.Cpe.name==str(target_cpe))).one()

dst_ip='10.152.0.0'
dst_mask=16

# select_srv6_path.add_with_srv6_insert(
#     cpe,
#     dst_ip='10.152.0.0',
#     dst_mask=16,
#     qos=0,
#     route_str="2,3,4"
# )


# select_traffic_class.add_with_get_traffic_class(cpe,
#                                                 src_ip='10.153.162.2',
#                                                 dst_ip='10.152.166.2',
#                                                 dst_port=1234,
#                                                 qos=1)

srv6_drop.add_with_ipv4_forward(cpe,
                                dst_ip='10.153.162.2',
                                dst_mask=16,
                                dst_mac="b8:ce:f6:9c:24:be",
                                bmv2_port=64
                                )

