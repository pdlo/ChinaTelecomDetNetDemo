from sqlmodel import select,Session
import pandas as pd
from typing import Dict,Union,Iterable,List

from src.orm import *
from sqlmodel import func


def get_link_latest_states_iter() -> List[Dict[str, Union[float,str]]]:
    with Session(engine) as session:
        subquary = (
            select(SgwLinkState,func.max(SgwLinkState.create_datetime))
            .group_by(SgwLinkState.link_id) # type: ignore
            .subquery()
        )
        quary = (
            select(
                SgwLink,
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
        results = session.exec(quary).all()
        def __to_row(result):
            link:SgwLink
            link,delay,rate,lost=result
            assert isinstance(link.src_sgw,Sgw)
            assert isinstance(link.dst_sgw,Sgw)
            return {
                'id':link.id,
                'src':link.src_sgw.name,
                'dst':link.dst_bmv2_port,
                "delay":delay,
                "rate":rate,
                "lost":lost
            }
        return list(map(__to_row,results))

def get_routes_iter() -> List[Dict[str, Union[float,str]]]:
    with Session(engine) as session:
        routes=session.exec(select(Route)).all()
        def __to_row(route:Route):
            assert isinstance(route.src_cpe,Cpe)
            assert isinstance(route.dst_cpe,Cpe)
            return {
                'id':route.id,
                'src':route.src_cpe.name,
                'dst':route.dst_cpe.name,
                'qos':route.qos,
                '路由':phase_route(int(i) for i in route.route.split(','))
            }
        return list(map(__to_row,routes))

def phase_route(ids:Iterable[int]) -> str:
    names:list[str]=[]
    with Session(engine) as session:
        for id in ids:
            statement=select(Sgw.name).where(Sgw.id==id)
            name:str = session.exec(statement).one()
            names.append(name)
        return ' → '.join(names)
        