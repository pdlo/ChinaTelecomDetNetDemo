from src.schedule.util import logger,make_variable_dict,config,ip_to_hex
from src.schedule import db_reader
from src import orm

from fabric import Connection,Result
from pathlib import PurePosixPath
from io import StringIO
import uuid

SDE=PurePosixPath("/root/bf-sde-9.1.0")
SDE_INSTALL=SDE/'install'
SDE_BIN=SDE_INSTALL/"bin"
CODE_PATH = PurePosixPath("/root/bfrt_code_dir")
VIRTUAL_MAC = '0x0a0a0a0a0a0a'

tofino_env=make_variable_dict(SDE=SDE,SDE_INSTALL=SDE_INSTALL)

def send_bfrt_python(cpe:orm.Cpe,code:str):
    ip,port = cpe.console_ip.split(':')
    c = Connection(
        host=ip,
        port=port,
        user=config['internal_network']['tofino']['user'],
        connect_kwargs={
            "password":"onl"
        }
    )
    code_file_path = CODE_PATH/f"{uuid.uuid4()}.py"
    c.put(StringIO(code),str(code_file_path))
    result:Result = c.run(f'bash /root/bf-sde-9.1.0/run_bfshell.sh -b {code_file_path}',env=tofino_env)
    logger.error(result.stderr)
    logger.info(result.stderr)
    c.close()

class SelectTrafficClassTable:
    @staticmethod
    def add_with_get_traffic_class(
        cpe:orm.Cpe,
        src_ip:str,
        dst_ip:str,
        dst_port:int,
        tos:int
    ):
        code=f"""
table=bfrt.srv6.pipe.Ingress.select_traffic_class
try:
    table.delete(
        dst_addr={ip_to_hex(dst_ip)}, 
        src_addr={ip_to_hex(src_ip)}, 
        dst_port={dst_port}, 
    )
except:
    pass
table.add_with_get_traffic_class(
    dst_addr={ip_to_hex(dst_ip)}, 
    src_addr={ip_to_hex(src_ip)}, 
    dst_port={dst_port}, 
    trafficclass={tos}
)
table.dump()
        """
        print(code)
        send_bfrt_python(cpe,code)

class SelectSrv6PathTable:
    @staticmethod
    def add_with_srv6_insert(
            cpe:orm.Cpe,
            dst_ip:str,
            dst_port:int,
            tos:int,
            route_str:str,
    ):
        route_list=[int(i) for i in route_str.split(',')]
        route_list.append(db_reader.get_sgw_locator_by_host_ip(dst_ip))
        num_segments=len(route_list)
        route_list=route_list+[0]*(5-num_segments)

        code=f"""
table=bfrt.srv6.pipe.Ingress.select_srv6_path
try:
    table.delete(
        dst_addr={ip_to_hex(dst_ip)},
        dst_port={dst_port},
        trafficclass={tos},
    )
except:
    pass
table.add_with_srv6_insert(
    dst_addr={ip_to_hex(dst_ip)},
    dst_port={dst_port},
    trafficclass={tos},
    num_segments={num_segments},
    last_entry={num_segments-1},
    src_mac={VIRTUAL_MAC},
    dst_mac={VIRTUAL_MAC},
    port={cpe.port_to_sgw},
    s1={db_reader.get_sgw_locator_by_id(route_list[0])},
    s2={db_reader.get_sgw_locator_by_id(route_list[1])},
    s3={db_reader.get_sgw_locator_by_id(route_list[2])},
    s4={db_reader.get_sgw_locator_by_id(route_list[3])},
    s5={db_reader.get_sgw_locator_by_id(route_list[4])},
)
table.dump()
"""
        print(code)
        send_bfrt_python(cpe,code)

    