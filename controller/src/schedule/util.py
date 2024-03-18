import logging
import toml
from pathlib import Path

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
file_handler = logging.FileHandler(str(root/"schedule.log"))
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

# 加载配置
config_file=root/"config.toml"
config = toml.load(config_file)
logger.info(f"加载配置文件\n{config}")