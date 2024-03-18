from sqlmodel import Session,select
from typing import Sequence
from src.orm import engine,Link,Business,Route

def static(connections:Sequence[Link],businesses:Sequence[Business]) -> list[Route]:
    routes = [
        Route(businesses=1,)
    ]
    # return {1:['0000:0000:0000:0000']}

route_algorithm=static

with Session(engine) as session:
    statement = select(Business)
    businesses = session.exec(statement).all()

def get_routings()->dict[int,list[str]]:
    with Session(engine) as session:
        statement = select(Link)
        connections = session.exec(statement).all()
    return route_algorithm(connections,businesses)
    

