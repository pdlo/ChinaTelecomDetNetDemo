from src.schedule.update_table import send_bfrt_python,SelectSrv6PathTable,SelectTrafficClassTable
from src.schedule import db_reader

code="""
select_srv6_path = bfrt.srv6.pipe.Ingress.select_srv6_path
select_srv6_path.add_with_srv6_insert(dst_addr=0x0a99b602, dst_port=0x0002, trafficclass=0x01,num_segments=0x03, last_entry=0x02, src_mac=0x000001533364, dst_mac=0x000001523364, port=64, s1=0x1, s2=0x2, s3=0x3, s4=0x4, s5=0x5)
"""

SelectSrv6PathTable.add_with_srv6_insert(db_reader.get_cpe_by_id(3),'10.152.166.2',6000,1,'4,3,3,2')
a=SelectTrafficClassTable.add_with_get_traffic_class(db_reader.get_cpe_by_id(3),'10.152.166.2',"10.153.168.2",8000,0)
print(a)