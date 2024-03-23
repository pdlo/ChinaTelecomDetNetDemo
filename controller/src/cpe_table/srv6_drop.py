from datetime import datetime

from src.cpe_table.utils import ip_to_hex,VIRTUAL_MAC
from src.cpe_table.send_bfrt_python import send
from src import orm

def add_with_get_traffic_class(
    cpe:orm.Cpe,
    *,
    dst_ip:str,
    dst_mask:int=32,
    src_mac:str=VIRTUAL_MAC,
    dst_mac:str,
    bmv2_port:int,
    send_code:bool=True
) -> str:
    """
    向cpe的srv6_drop表下发一行，且action为ipv4_forward
    """
    code=f"""
#{datetime.now().isoformat()}
table=bfrt.srv6.pipe.Ingress.srv6_drop
try:
    table.delete(
        dst_addr={ip_to_hex(dst_ip)}, 
        dst_addr_p_length={dst_mask}, 
    )
    print("已删除原有流表项")
except:
    pass
table.add_with_ipv4_forward(
    dst_addr={ip_to_hex(dst_ip)}, 
    dst_addr_p_length={dst_mask}, 
    src_mac={src_mac}, 
    dst_mac={dst_mac},
    port={bmv2_port}
)
table.dump()
    """
    if send_code:
        send(cpe,code)
    return code