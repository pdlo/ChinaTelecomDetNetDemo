# import sys
# from pathlib import Path
# root = Path(__file__).parent.parent.parent
# sys.path.append(str(root))
# from controller.orm import engine

from dataclasses import dataclass
from sqlmodel import Session,select
from ..orm import engine,Connection,Business

def greedy(connections,businesses):
    #TODO
    return {1:['0000:0000:0000:0000']}


route_algorithm=greedy

with Session(engine) as session:
    statement = select(Business)
    businesses = session.exec(statement).all()

def get_routings()->dict[int,list]:
    with Session(engine) as session:
        statement = select(Connection)
        connections = session.exec(statement).all()
        route_algorithm(connections,businesses)

