"""
包含各个表的orm。
运行此文件将会建表。
"""
from typing import Optional
from sqlmodel import Field, SQLModel, create_engine  #, Relationship  暂时不使用此功能，请手动处理连接关系
from pathlib import Path
from datetime import datetime

__all__=['Sgw','SgwInterface','SgwLink','SgwLinkState','Cpe','Business','Route','engine']

class Sgw(SQLModel, table=True):
    """
    此表id被作为外键，不应该删除数据。
    此表是手动根据网络配置填写的。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    console_ip:str = Field(description="用于ssh的ipv4地址和端口，使用类似219.242.112.215:6153的格式")
    srv6_locator:str = Field(description="半个ipv6地址（64bit），使用类似2001:0db8的格式")

class SgwInterface(SQLModel, table=True):
    """
    此表id被作为外键，不应该删除数据。
    此表是手动根据网络配置填写的。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    name:str
    sgw_id:int = Field(foreign_key="sgw.id")
    bmv2_port:Optional[int] = Field(default=None,description="交换机网卡对应的bmv2 port")

class SgwLink(SQLModel, table=True):
    """
    id被作为外键，此表中数据不应该删除。
    此表是手动根据配置的网络填写的，程序不应修改。
    连接有方向（因为int）。两个sgw之间需要添加两个连接。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    sgw_id_1:int = Field(foreign_key="sgw.id")
    interface_id_1:int  = Field(foreign_key="sgwinterface.id")
    sgw_id_2:int = Field(foreign_key="sgw.id")
    interface_id_2:int = Field(foreign_key="sgwinterface.id")

class SgwLinkState(SQLModel, table=True):
    """
    由int程序写入
    schedule程序读取
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    link_id:int= Field(foreign_key="sgwlink.id")
    create_datetime:datetime
    delay:Optional[int]=Field(default=None)
    rate:Optional[int]=Field(default=None)
    lost:Optional[float]=Field(default=None)

class Cpe(SQLModel, table=True):
    """
    id被作为外键，此表中数据不应该删除。
    此表是手动根据配置的网络填写的，程序不应修改。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    name:str
    console_ip:str = Field(description="用于ssh的ipv4地址和端口，使用类似219.242.112.215:6153的格式")
    connect_sgw:int = Field(foreign_key="sgw.id")
    srv6_locator:str = Field(description="半个ipv6地址（64bit），使用类似2001:0db8的格式")

class Business(SQLModel, table=True):
    """
    所有被特殊对待的业务。
    表中的业务将按照route中对应的表项进行路由。
    不在表中的业务或tos为0按照默认路由走
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    src_ip:str = Field(description="源主机的ip地址")
    src_cpe_id:int = Field(foreign_key="cpe.id",description="入网cpe")
    dst_ip:str = Field(description="目的主机的ip地址")
    dst_port:str = Field(description="目的主机的端口号")
    dst_cpe_id:int = Field(foreign_key="cpe.id",description="出网cpe")
    delay:Optional[int]=Field(default=None)
    rate:Optional[int]=Field(default=None)
    loss:Optional[float]=Field(default=None)
    disorder:Optional[float]=Field(default=None)
    tos:Optional[int]=Field(default=0,description="8bit，0~255")

class Route(SQLModel, table=True):
    """
    此表由schedule程序写入。仅用于展示。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    src_cpe_id:int=Field(foreign_key="cpe.id",description="入网cpe")
    dst_cpe_id:int=Field(foreign_key="cpe.id",description="出网cpe")
    tos:int=Field(description="8bit，0~255")
    route:str= Field(description="用逗号分割的若干个sgw.id。(不包含cpe)")

sqlite_file=Path(__file__).parent.parent/"database.db"
sqlite_url = f"sqlite:///{sqlite_file}"
engine = create_engine(sqlite_url, echo=True)

def main():
    SQLModel.metadata.create_all(engine)

if __name__ == "__main__":
    main()