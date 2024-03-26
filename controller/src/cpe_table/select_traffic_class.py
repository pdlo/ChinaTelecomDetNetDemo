from datetime import datetime

from src.cpe_table.utils import ip_to_hex,VIRTUAL_MAC
from src.cpe_table.send_bfrt_python import send
from src import orm

def add_with_get_traffic_class(
    cpe:orm.Cpe,
    *,
    src_ip:str,
    src_port:int,
    dst_ip:str,
    dst_port:int,
    qos:int,
    send_code:bool=True
) -> str:
    """
    向cpe的select_traffic_class表下发一行，且action为get_traffic_class
    """
    code=f"""
#{datetime.now().isoformat()}
table=bfrt.srv6.pipe.Ingress.select_traffic_class
try:
    table.delete(
        dst_addr={ip_to_hex(dst_ip)}, 
        src_addr={ip_to_hex(src_ip)}, 
        dst_port={dst_port}, 
        src_port={src_port},
    )
except:
    pass
table.add_with_get_traffic_class(
    dst_addr={ip_to_hex(dst_ip)}, 
    src_addr={ip_to_hex(src_ip)}, 
    dst_port={dst_port}, 
    trafficclass={qos}
)
table.dump()
    """
    if send_code:
        send(cpe,code)
    return code