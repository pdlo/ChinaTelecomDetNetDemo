"""
提供cpe的p4代码里的各个流表相关的接口,用于添加和删除流表。
运行此模块时会下发初始的流表。
"""
from src.cpe_table import select_srv6_path,select_traffic_class,srv6_drop,select_srv6_path_without_qos
from src.cpe_table.send_bfrt_python import send