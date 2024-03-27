from sqlalchemy import Engine
from sqlmodel import select,Session,func
from typing import Sequence,Union
from sqlalchemy.exc import NoResultFound
import streamlit as st 
import pandas as pd

from src.cpe_table import select_traffic_class
from src.orm import Cpe,Host,Business,SgwLink,SgwLinkState,Sgw,Route,get_engine as get_engine_original
from src.config import config

@st.cache_resource
def get_engine() -> Engine:
    print("创建数据处理engine")
    return get_engine_original()

def add_business(
        qos:int,
        src_name:str,
        src_port:int,
        dst_name:str,
        dst_port:int,
        delay:Union[int,None],
        rate:Union[int,None],
        loss:Union[float,None],
        disorder:Union[float,None]
    ) -> None:
    if delay==0:
        delay=None
    if rate==0:
        rate=None
    if loss==0:
        loss=None
    if disorder==0:
        disorder=None

    with Session(get_engine()) as session:
        if src_name>dst_name:
            src_name,dst_name=dst_name,src_name
        
        def get_host_by_name(host_name):
            try:
                return session.exec(select(Host).where(Host.name==host_name)).one()
            except NoResultFound as e:
                # raise Exception(f"未知主机 {host_name}")
                raise e
        src = get_host_by_name(src_name)
        dst = get_host_by_name(dst_name)
        assert isinstance(src.cpe,Cpe)
        src_cpe = src.cpe
        assert isinstance(dst.cpe,Cpe)
        dst_cpe = dst.cpe

        statement = select(Business).where(
            Business.src_host_id==src.id,
            Business.dst_host_id==dst.id,
            Business.dst_port==dst_port,
        )
        business=session.exec(statement).one_or_none()
        if business is None:
            business=Business(
                src_host_id=src.id,  # type: ignore
                src_port=src_port,
                dst_host_id=dst.id,  # type: ignore
                dst_port=dst_port,
                delay=delay,
                rate=rate,
                loss=loss,
                disorder=disorder,
                qos=qos,
            )
        else:
            business.delay=delay
            business.rate=rate
            business.loss=loss
            business.disorder=disorder
            business.qos=qos
        session.add(business)

        select_traffic_class.add_with_get_traffic_class(
            src_cpe,
            src_ip=src.ip,
            src_port=src_port,
            dst_ip=dst.ip,
            dst_port=dst_port,
            qos=qos,
            send_code=config['app']['send_table']
        )

        select_traffic_class.add_with_get_traffic_class(
            dst_cpe,
            src_ip=dst.ip,
            src_port=dst_port,
            dst_ip=src.ip,
            dst_port=src_port,
            qos=qos,
            send_code=config['app']['send_table']
        )
        
        session.commit()
        
def get_latest_link_states() -> pd.DataFrame:
    with Session(get_engine()) as session:
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
                '序号':link.id,
                '连接':f"{link.src_sgw.name} - {link.dst_sgw.name}",
                "时延(ms)":'-' if delay is None else delay/1000,
                "吞吐量(byte/s)":'-' if rate is None else rate,
                "丢包率(%)":'-' if lost is None else lost,
            }
        return pd.DataFrame(map(__to_row,results))

@st.cache_data
def get_all_routes() -> pd.DataFrame:
    with Session(get_engine()) as session:
        routes=session.exec(select(Route)).all()
        def __to_row(route:Route):
            assert isinstance(route.src_cpe,Cpe)
            assert isinstance(route.dst_cpe,Cpe)
            return {
                '序号':route.id,
                '源主机':route.src_cpe.name,
                '目的主机':route.dst_cpe.name,
                '流量等级':route.qos,
                '路由':__phase_route([int(i) for i in route.route.split(',')])
            }
        return pd.DataFrame(map(__to_row,routes))

def get_route_by_host(src:Host,dst:Host,qos:int) -> str:
    with Session(get_engine()) as session:
        assert isinstance(src.cpe,Cpe)
        assert isinstance(dst.cpe,Cpe)
        statement=select(Route.route).where(Route.src_cpe_id == src.cpe_id,Route.dst_cpe_id==dst.cpe_id,Route.qos==qos)
        route=session.exec(statement).one()
        return __phase_route([int(i) for i in route.split(',')])

@st.cache_data
def __phase_route(ids:Sequence[int]) -> str:
    names:list[str]=[]
    with Session(get_engine()) as session:
        for id in ids:
            statement=select(Sgw.name).where(Sgw.id==id)
            name:str = session.exec(statement).one()
            names.append(name)
        return ' → '.join(names)
        
def get_bussiness()->pd.DataFrame:
    with Session(get_engine()) as session:
        bussinesses=session.exec(select(Business)).all()
        def __to_row(bussiness:Business):
            assert isinstance(bussiness.src_host,Host)
            assert isinstance(bussiness.dst_host,Host)
            assert isinstance(bussiness.qos,int)
            make_placeholder = lambda x:'-' if x is None else x
            return {
                '序号':bussiness.id,
                "源主机":bussiness.src_host.name,
                '源端口':bussiness.src_port,
                "目的主机":bussiness.dst_host.name,
                '目的端口':bussiness.dst_port,
                '时延需求(μs)':make_placeholder(bussiness.delay),
                '带宽需求':make_placeholder(bussiness.rate),
                '丢包率需求':make_placeholder(bussiness.loss),
                "乱序需求":make_placeholder(bussiness.disorder),
                '流量等级':bussiness.qos,
                '路由':get_route_by_host(bussiness.src_host,bussiness.dst_host,bussiness.qos)
            }
        return pd.DataFrame(map(__to_row,bussinesses))

if __name__ == "__main__":
    add_business(0,'162',5165,'166',1234,546546,0,0,0)
    print(get_bussiness()[0]['时延需求(μs)'])