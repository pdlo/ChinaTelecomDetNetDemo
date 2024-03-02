"""
1. 每隔一定时间运行一次
2. 读取每一跳的时延带宽丢包率
3. 计算三个路由,向cpe下发路由表
"""

from datetime import datetime,timedelta
import logging
from .get_routing import get_routings
from .update_table import update_table
from .util import config

logging.basicConfig(encoding='utf-8', level=logging.INFO)

def main():
    last_schedule_time=datetime.min
    while(True):
        now_time=datetime.now()
        if now_time-last_schedule_time < timedelta(seconds=config["schedule_interval"]):
            continue
        last_schedule_time=now_time
        routings = get_routings()
        for id,table in routings.items():
            update_table(id,table)
        logging.info(f"{datetime.now()} 下发流表")