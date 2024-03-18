"""
包含各个表的orm
运行此文件建表
"""
from typing import Optional
from sqlmodel import Field, SQLModel, create_engine,JSON
from pathlib import Path
from datetime import datetime

#sgw
class Switch(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    srv6_locator:str = Field(description="64bit，使用类似2001:0db8的格式")

class Link(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    
    switch_id_1:int = Field(foreign_key="switch.id")
    interface_id_1:int  = Field(foreign_key="interface.id")
    switch_id_2:int = Field(foreign_key="switch.id")
    interface_id_2:int = Field(foreign_key="interface.id")

class Interface(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name:str
    switch_id:int = Field(foreign_key="switch.id")
    bmv2_port:Optional[int] = Field(default=-1,description="交换机网卡对应的bmv2 port")

class LinkState(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    link_id:int= Field(foreign_key="link.id")
    create_datetime:datetime
    delay:Optional[int]=Field(default=None)
    rate:Optional[int]=Field(default=None)
    lost:Optional[float]=Field(default=None)



class Business(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    src_ip:str = Field(description="源主机的ip地址")
    src_port:str = Field(description="源主机的端口号")
    src_switch_id:int = Field(foreign_key="switch.id",description="入网sgw")
    src_ip:str = Field(description="目的主机的ip地址")
    src_port:str = Field(description="目的主机的端口号")
    dst_switch_id:int = Field(foreign_key="switch.id",description="出网sgw")
    delay:Optional[int]
    rate:Optional[int]
    loss:Optional[float]
    disorder:Optional[float]
    create_datetime:datetime
    enabled:bool

class Route(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    business_id:int = Field(foreign_key="business.id")
    create_datetime:datetime
    route:str = Field(description="逗号分割的switch_id")


sqlite_file=Path(__file__).parent.parent/"database.db"
sqlite_url = f"sqlite:///{sqlite_file}"
engine = create_engine(sqlite_url, echo=False)

def main():
    SQLModel.metadata.create_all(engine)

if __name__ == "__main__":
    main()