from datetime import datetime

from src.cpe_table.utils import ip_to_hex,VIRTUAL_MAC,mac_to_hex
from src.cpe_table.send_bfrt_python import send 
from src.cpe_table import read_db
from src import orm

def add_with_srv6_insert(
    cpe:orm.Cpe,
    *,
    dst_ip:str,
    dst_mask:int,
    qos:int,
    src_mac:str=VIRTUAL_MAC,
    dst_mac:str=VIRTUAL_MAC,
    route_str:str,
    send_code:bool=True
) -> str:
    """route是所有数据包经过的Sgw.id。第一个是冗余的，将被删除。
    """
    sgw_id_route_list=[int(i) for i in route_str.split(',')[1:]]
    locator_route_list=[read_db.get_sgw_sid_by_id(i) for i in sgw_id_route_list]
    locator_route_list.append(read_db.get_cpe_sid_by_subnet_ip(dst_ip,dst_mask))
    num_segments=len(locator_route_list)
    sgw_id_route_list=locator_route_list+(5-num_segments)*["0x"+'0'*32]

    code=f"""
#{datetime.now().isoformat()}
table=bfrt.srv6.pipe.Ingress.select_srv6_path
try:
    table.delete(
        dst_addr={ip_to_hex(dst_ip)},
        dst_addr_p_length={dst_mask},
        trafficclass={qos},
    )
except:
    pass
table.add_with_srv6_insert(
    dst_addr={ip_to_hex(dst_ip)},
    dst_addr_p_length={dst_mask}, 
    trafficclass={qos},
    num_segments={num_segments},
    last_entry={num_segments-1},
    src_mac={mac_to_hex(src_mac)},
    dst_mac={mac_to_hex(dst_mac)},
    port={cpe.port_to_sgw},
    s1={sgw_id_route_list[0]},
    s2={sgw_id_route_list[1]},
    s3={sgw_id_route_list[2]},
    s4={sgw_id_route_list[3]},
    s5={sgw_id_route_list[4]},
)
table.dump()
    """
    if send_code:
        send(cpe,code)
    return code