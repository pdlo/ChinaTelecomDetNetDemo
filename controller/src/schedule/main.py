from datetime import datetime,timedelta
from .get_routing import get_routings
from .update_table import update_table

interval = 10 #每隔多长时间重新计算一次

def main():
    last_schedule_time=datetime.min
    while(True):
        now_time=last_schedule_time
        if datetime.now() < timedelta(seconds=interval):
            continue
        last_schedule_time=now_time
        routings = get_routings()
        for id,table in routings.items():
            update_table(id,table)
