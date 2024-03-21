import logging
import toml
from pathlib import Path
import typing
from datetime import datetime

__all__=['root','logger',"config"]

root=Path(__file__).parent.parent.parent

# 配置 logger
logger = logging.getLogger("schedule")
logger.setLevel(logging.DEBUG)
# 令logger打印到屏幕
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter(
    fmt='%(asctime)s - %(name)s - %(levelname)s > %(message)s',
    datefmt= '%Y-%m-%d %H:%M:%S'
    )
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)
# 令logger保存到文本文件
file_handler = logging.FileHandler(str(root/"logs"/datetime.now().strftime('schedule %Y%m%d %H-%M-%S.log')),encoding='utf8')
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

# 加载配置
config_file=root/"config.toml"
config = toml.load(config_file)
logger.info(f"加载配置文件\n{config}")

def make_variable_dict(**kwargs)-> typing.Dict[str, str]:
    return {str(k):str(v) for k,v in kwargs.items()}

def ip_to_hex(ip_address:str) -> str:
    # 将点分十进制IP地址拆分成四个部分
    octets = ip_address.split('.')
    # 将每个部分转换为十六进制并用0填充至两位
    hex_octets = [hex(int(octet))[2:].zfill(2) for octet in octets]
    # 拼接每个部分并在开头添加'0x'前缀
    hex_ip = '0x' + ''.join(hex_octets)
    return hex_ip