"""
1. 每隔一定时间运行一次
2. 读取当前网络状态
3. 计算各类服务的路径
4. 下发路由表
"""
from datetime import datetime, timedelta
from functools import partial
from itertools import product

from src.config import config
from src.schedule.util import logger
from src.schedule.get_data import get_all_src_dst_paths, get_delay, get_bandwidth
from src.schedule.multipath_algorithm import low_delay, high_bandwidth
from src.orm import get_session, NetPath, engine, MRN
from src.p4_command_controller.tofino import Tofino
from sqlmodel import Session, select
from typing import Optional
from ipaddress import IPv4Address

"""
字典映射：其中等级0对于7777端口，1对于10054端口...
"""
trafficclass_to_port = {
    0: 7777,
    1: 10054,
    2: 6789,
    3: 9000
}

trafficclass_to_dscp = {
    0: 0,
    1: 128,
    2: 0,
    3: 124
}

# 获取网络数据的方法->traffic class值->
data_factory_to_algorithm = {
    get_delay: {
        0x11: partial(low_delay, s_delay=20),
        0x12: partial(low_delay, s_delay=40),
    },
    # TODO
    # get_bandwidth:{}
}

"""
实例化的p4交换机对象，具体参数根据要连接的交换机进行填写
"""
switch = Tofino(ssh_ip="xxxxxx", ssh_port=22, user="xxxx", password="xxxxx")


def get_port_by_trafficclass(trafficclass):
    """
    :param trafficclass:
    :return: 等级对应的端口号
    """
    return trafficclass_to_port.get(trafficclass, "Unknown trafficclass")


def get_dscp_by_trafficclass(trafficclass):
    """
    :param trafficclass:
    :return: dsap表对应的端口号
    """
    return trafficclass_to_dscp.get(trafficclass, "Unknown trafficclass")


def get_ssh_ips_by_path(session: Session, path: NetPath) -> (Optional[IPv4Address], Optional[IPv4Address]):
    """
       根据路径对象获取源节点和目标节点的ssh_ip。

       Args:
           session (Session): 数据库会话对象。
           path (NetPath): 路径对象。

       Returns:
           Tuple[Optional[IPv4Address], Optional[IPv4Address]]: 源节点和目标节点的ssh_ip，如果未找到则返回None。
       """
    # 获取源节点的 MRN 实例
    src_mrn = session.exec(select(MRN).where(MRN.id == path.src_mrn_id)).one_or_none()
    # 获取目标节点的 MRN 实例
    dst_mrn = session.exec(select(MRN).where(MRN.id == path.dst_mrn_id)).one_or_none()

    # 返回源节点和目标节点的 ssh_ip
    return (src_mrn.ssh_ip if src_mrn else None, dst_mrn.ssh_ip if dst_mrn else None)


def get_match_params(src_ssh_ip, dst_ssh_ip, traffic_class: int):
    """
    :param src_ssh_ip:
    :param dst_ssh_ip:
    :param traffic_class:
    :return: 关于p4匹配表中的匹配参数
    """
    match_params_trafficclass_set_src = {
        'src_ipv4': src_ssh_ip,
        'dst_ipv4': dst_ssh_ip,
        'src_port': get_port_by_trafficclass(traffic_class)
        # 你可以在这里添加更多参数，根据你的需求
    }

    match_params_trafficclass_set_dst = {
        'src_ipv4': src_ssh_ip,
        'dst_ipv4': dst_ssh_ip,
        'src_port': get_port_by_trafficclass(traffic_class)
    }

    match_params_dscp_get = {
        "dst_ipv4": dst_ssh_ip,
        "trafficclass": traffic_class
    }
    return match_params_trafficclass_set_src, match_params_trafficclass_set_dst, match_params_dscp_get


def get_action_params(traffic_class: int):
    """
    :param traffic_class:
    :return: dscp表的匹配参数
    """
    action_trafficclass_set_dst = {
        "trafficclass": traffic_class
    }
    action_trafficclass_set_src = {
        "trafficclass": traffic_class
    }
    action_dscp_get = {
        "dscp": get_dscp_by_trafficclass(traffic_class)
    }
    return action_trafficclass_set_src, action_trafficclass_set_dst, action_dscp_get


def main():
    with get_session() as session:
        src_dst_to_paths = get_all_src_dst_paths(session)

    if __name__ != "__main__":
        raise Exception("试图import此代码")

    last_schedule_time = datetime.min
    logger.info("已启动调度程序")
    try:
        while (True):
            now_time = datetime.now()
            if now_time - last_schedule_time < timedelta(seconds=config["schedule"]["interval"]):
                continue
            with get_session() as session:
                for (
                        (src_dst, path_id_to_Path),
                        (data_factory, traffic_class_to_algorithm)
                ) in (
                        product(
                            src_dst_to_paths.items(),
                            data_factory_to_algorithm.items()
                        )
                ):
                    for traffic_class, algorithm in traffic_class_to_algorithm.items():
                        data = data_factory(path_id_to_Path.keys(), session)
                        path_id = algorithm(data)
                        update_route(traffic_class, path_id_to_Path[path_id])
                        logger.info(f"已下发流表:{src_dst},{traffic_class=},{path_id=}")
            last_schedule_time = now_time
            logger.info(f"已下发流表")
    except KeyboardInterrupt:
        logger.info("已停止调度程序")


def update_route(traffic_class: int, path: NetPath):
    """
    :param traffic_class:
    :param path:
    进行表项更新，其中switch.update_table_entry是TOfino中的一个功能
    """
    with Session(engine) as session:
        path = session.get(NetPath, path.id)
        if path:
            src_ssh_ip, dst_ssh_ip = get_ssh_ips_by_path(session, path)  # 通过path: NetPath从表中得到ip地址
            if src_ssh_ip is None or dst_ssh_ip is None:
                raise ValueError("无法获取源或目标节点的 IP 地址")

            match_params_trafficclass_set_src, match_params_trafficclass_set_dst, match_params_dscp_get = get_match_params(
                src_ssh_ip, dst_ssh_ip, traffic_class)
        else:
            raise ValueError("NetPath not found.")

    action_trafficclass_set_src, action_trafficclass_set_dst, action_dscp_get = get_action_params(traffic_class)

    switch.update_table_entry(table="trafficclass_set_dst", match_params=match_params_trafficclass_set_dst,
                              action="get_traffic_class_dst",
                              action_params=action_trafficclass_set_dst)
    switch.update_table_entry(table="trafficclass_set_src", match_params=match_params_trafficclass_set_src,
                              action="get_traffic_class_src",
                              action_params=action_trafficclass_set_src)
    switch.update_table_entry(table="dscp_get", match_params=match_params_dscp_get, action="set_dscp",
                              action_params=action_dscp_get)


main()
