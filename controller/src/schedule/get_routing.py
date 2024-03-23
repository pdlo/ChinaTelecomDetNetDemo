from sqlmodel import Session,select
from typing import Sequence
from src.orm import engine,Business,Route,SgwLink,SgwLinkState
from sqlmodel import func
from typing import List,Optional
from dataclasses import dataclass
from datetime import datetime

@dataclass
class CurrentLinkState:
    id:int
    sgw_id_1:int
    sgw_id_2:int
    delay:Optional[int]
    rate:Optional[int]
    lost:Optional[float]

def get_link_states()->List[CurrentLinkState]:
    with Session(engine) as session:
        subquary = (
            select(SgwLinkState,func.max(SgwLinkState.create_datetime))
            .group_by(SgwLinkState.link_id) # type: ignore
            .subquery()
        )
        quary = (
            select(
                SgwLink.id,
                SgwLink.src_sgw_id,
                SgwLink.dst_sgw_id,
                subquary.c.delay,
                subquary.c.rate,# type: ignore
                subquary.c.lost,
            )
            .outerjoin_from(
                SgwLink,
                subquary,
                SgwLink.id==subquary.c.link_id # type: ignore
            )
            
        ) 
        results = session.exec(quary)
    return [CurrentLinkState(*i) for i in results]

def static(connections:Sequence[CurrentLinkState],businesses:Sequence[Business]) -> List[Route]:
    print(connections,businesses)
    routes = [
        # Route(business_id=1,create_datetime=datetime.now(),route="1,2,3,4,5")
    ]
    return routes


route_algorithm=static

def get_routings()->List[Route]:
    with Session(engine) as session:
        statement = select(Business)
        businesses = session.exec(statement).all()
        connections=get_link_states()
    return route_algorithm(connections,businesses)