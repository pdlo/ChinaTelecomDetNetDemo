from datetime import datetime

from src.cpe_table.utils import ip_to_hex,VIRTUAL_MAC,mac_to_hex
from src.cpe_table.send_bfrt_python import send 
from src.cpe_table import db_reader
from src import orm

def add_with_srv6_insert(
    cpe:orm.Cpe,
    *,
    src_ip:str,
    dst_ip:str,
    dst_port:int,
    tos:int,
    src_mac:str=VIRTUAL_MAC,
    dst_mac:str=VIRTUAL_MAC,
    route_str:str,
    send_code:bool=True
) -> str:
    route_list=[int(i) for i in route_str.split(',')]
    route_list.append(db_reader.get_sgw_locator_by_host_ip(dst_ip))
    num_segments=len(route_list)
    route_list=route_list+[0]*(5-num_segments)

    code=f"""
#{datetime.now().isoformat()}
table=bfrt.srv6.pipe.Ingress.select_srv6_path
try:
    table.delete(
        src_addr={ip_to_hex(src_ip)}
        dst_addr={ip_to_hex(dst_ip)},
        dst_port={dst_port},
        trafficclass={tos},
    )
except:
    pass
table.add_with_srv6_insert(
    src_addr={ip_to_hex(src_ip)}
    dst_addr={ip_to_hex(dst_ip)},
    dst_port={dst_port},
    trafficclass={tos},
    num_segments={num_segments},
    last_entry={num_segments-1},
    src_mac={mac_to_hex(src_mac)},
    dst_mac={mac_to_hex(dst_mac)},
    port={cpe.port_to_sgw},
    s1={db_reader.get_forward_sid_by_id(route_list[0])},
    s2={db_reader.get_forward_sid_by_id(route_list[1])},
    s3={db_reader.get_forward_sid_by_id(route_list[2])},
    s4={db_reader.get_forward_sid_by_id(route_list[3])},
    s5={db_reader.get_forward_sid_by_id(route_list[4])},
)
table.dump()
    """
    if send_code:
        send(cpe,code)
    return code