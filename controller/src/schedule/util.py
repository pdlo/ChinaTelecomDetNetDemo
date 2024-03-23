import logging
from pathlib import Path
from datetime import datetime

__all__=['root','logger']


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