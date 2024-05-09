"""
1. 每隔一定时间运行一次
2. 读取当前网络状态
3. 计算各类服务的路径
4. 下发路由表
"""
from datetime import datetime,timedelta
from functools import partial
from itertools import product

from src.config import config
from src.schedule.util import logger
from src.schedule.get_data import get_all_src_dst_paths,get_delay,get_bandwidth
from src.schedule.multipath_algorithm import low_delay,high_bandwidth
from src.orm import get_session,NetPath

#获取网络数据的方法->traffic class值->
data_factory_to_algorithm={
    get_delay:{
        0x11:partial(low_delay,s_delay=20),
        0x12:partial(low_delay,s_delay=40),
    },
    # TODO
    # get_bandwidth:{} 
}

def main():
    with get_session() as session:
        src_dst_to_paths = get_all_src_dst_paths(session)

    if __name__!="__main__":
        raise Exception("试图import此代码")

    last_schedule_time=datetime.min
    logger.info("已启动调度程序")
    try:
        while(True):
            now_time=datetime.now()
            if now_time-last_schedule_time < timedelta(seconds=config["schedule"]["interval"]):
                continue
            with get_session() as session:
                for (
                        (src_dst,path_id_to_Path),
                        (data_factory,traffic_class_to_algorithm)
                    ) in (
                    product(
                        src_dst_to_paths.items(),
                        data_factory_to_algorithm.items()
                    )
                ):
                    for traffic_class , algorithm in traffic_class_to_algorithm.items():
                        data = data_factory(path_id_to_Path.keys(),session)
                        path_id=algorithm(data)
                        update_route(traffic_class,path_id_to_Path[path_id])
                        logger.info(f"已下发流表:{src_dst},{traffic_class=},{path_id=}")
            last_schedule_time=now_time
            logger.info(f"已下发流表")
    except KeyboardInterrupt:
        logger.info("已停止调度程序")

def update_route(traffic_class:int,path:NetPath):
    ...

main()