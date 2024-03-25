from fabric import Connection,Result
from pathlib import PurePosixPath
from io import StringIO
import uuid

from src import orm
from src.cpe_table.utils import make_variable_dict
from src.config import config

__all__=['send']

SDE=PurePosixPath("/root/bf-sde-9.1.0")
SDE_INSTALL=SDE/'install'
SDE_BIN=SDE_INSTALL/"bin"
CODE_PATH = PurePosixPath("/root/bfrt_code_dir")

tofino_env=make_variable_dict(SDE=SDE,SDE_INSTALL=SDE_INSTALL)

def send(cpe:orm.Cpe,code:str) -> str:
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
    result:Result = c.run(f'bash /root/bf-sde-9.1.0/run_bfshell.sh -b {code_file_path}',env=tofino_env,hide=True)
    # c.run(f"rm {code_file_path}")
    c.close()
    if len(result.stderr)>0:
        raise Exception(f"命令运行报错:\n{result.stdout}")
    return result.stdout