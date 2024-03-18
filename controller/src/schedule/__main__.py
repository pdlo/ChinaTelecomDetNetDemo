"""
1. 每隔一定时间运行一次
2. 读取每一跳的时延带宽丢包率
3. 计算三个路由,向cpe下发路由表
"""

from datetime import datetime,timedelta
from src.schedule.get_routing import get_routings
from src.schedule.update_table import update_table
from src.schedule.util import config,logger

if __name__!="__main__":
    raise Exception("试图import此代码")

last_schedule_time=datetime.min
logger.info("已启动调度程序")
try:
    while(True):
        now_time=datetime.now()
        if now_time-last_schedule_time < timedelta(seconds=config["schedule_interval"]):
            continue
        last_schedule_time=now_time
        routings = get_routings()
        for id,table in routings.items():
            update_table(id,table)
        logger.info(f"已下发流表")
except KeyboardInterrupt:
    logger.info("已停止调度程序")
