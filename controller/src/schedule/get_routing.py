# import sys
# from pathlib import Path
# root = Path(__file__).parent.parent.parent
# sys.path.append(str(root))
# from controller.orm import engine

from dataclasses import dataclass
from sqlmodel import Session,select
from typing import Sequence
from ..orm import engine,Connection,Business

# def greedy(connections:Sequence[Connection],businesses:Sequence[Business]) -> dict[int, list[str]]:
#     """使用贪婪算法计算符合业务要求的路由"""
#     return {1:['0000:0000:0000:0000']}

def static(connections:Sequence[Connection],businesses:Sequence[Business]) -> dict[int, list[str]]:
    return {1:['0000:0000:0000:0000']}

route_algorithm=static

with Session(engine) as session:
    statement = select(Business)
    businesses = session.exec(statement).all()

def get_routings()->dict[int,list[str]]:
    with Session(engine) as session:
        statement = select(Connection)
        connections = session.exec(statement).all()
    return route_algorithm(connections,businesses)
    

