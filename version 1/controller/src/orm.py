"""
包含各个表的orm。
运行此文件将会建表。
"""
from typing import Optional,List
from sqlmodel import Field, SQLModel, create_engine, Relationship
from pathlib import Path
from datetime import datetime

__all__=['Sgw','SgwInterface','SgwLink','SgwLinkState','Cpe','Host','Business','Route','get_engine']

class Sgw(SQLModel, table=True):
    """
    此表id被作为外键，不应该删除数据。
    此表是手动根据网络配置填写的。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    console_ip:str = Field(description="用于ssh的ipv4地址和端口，使用类似219.242.112.215:6153的格式")
    srv6_locator:str = Field(description="半个ipv6地址（64bit），使用类似2001:0db8的格式")

    sgwlink:List['SgwLink'] = Relationship(back_populates='src_sgw',sa_relationship_kwargs=dict(foreign_keys="[SgwLink.src_sgw_id]"))

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

    src_sgw_id:int = Field(foreign_key="sgw.id")
    src_sgw:Optional[Sgw] = Relationship(back_populates='sgwlink',sa_relationship_kwargs=dict(foreign_keys="[SgwLink.src_sgw_id]"))
    src_bmv2_port:int

    dst_sgw_id:int = Field(foreign_key="sgw.id")
    dst_sgw:Optional[Sgw] = Relationship(sa_relationship_kwargs=dict(foreign_keys="[SgwLink.dst_sgw_id]"))
    dst_bmv2_port:int

    link_state:Optional['SgwLinkState'] = Relationship(back_populates='link')
    
class SgwLinkState(SQLModel, table=True):
    """
    由int程序写入
    schedule程序读取
    """
    id: Optional[int] = Field(default=None, primary_key=True)

    link_id:int= Field(foreign_key="sgwlink.id")
    link:Optional[SgwLink]=Relationship(back_populates='link_state')

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
    port_to_sgw:int = Field(description="p4程序中的端口号")
    srv6_locator:str = Field(description="使用类似2001:0db8的格式,32bit")
    subnet_ip:str
    subnet_mask:int 
    host:List['Host']= Relationship(back_populates='cpe')

    route:List['Route'] = Relationship(back_populates='src_cpe',sa_relationship_kwargs=dict(foreign_keys="[Route.src_cpe_id]"))


class Host(SQLModel, table=True):
    """
    id被作为外键，此表中数据不应该删除。
    此表是手动根据配置的网络填写的，程序不应修改。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    name:str
    ip : str
    mac : str

    cpe_id:int = Field(foreign_key="cpe.id",description="入网cpe")
    cpe_bmv2_port:int
    cpe:Optional[Cpe] = Relationship(back_populates='host')

    src_business:List['Business'] = Relationship(back_populates="src_host",sa_relationship_kwargs=dict(foreign_keys="[Business.src_host_id]"))
    dst_business:List['Business'] = Relationship(back_populates="dst_host",sa_relationship_kwargs=dict(foreign_keys="[Business.dst_host_id]"))


class Business(SQLModel, table=True):
    """
    所有被特殊对待的业务。
    表中的业务将按照route中对应的表项进行路由。
    不在表中的业务或qos为0按照默认路由走
    现在不区分src和dst，src和dst按照字典顺序排序
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    
    src_host_id:str = Field(foreign_key="host.id")
    src_host:Optional[Host] = Relationship(back_populates="src_business",sa_relationship_kwargs=dict(foreign_keys="[Business.src_host_id]"))
    src_port:int

    dst_host_id:str = Field(foreign_key="host.id",description="目的主机的ip地址")
    dst_host:Optional[Host] = Relationship(back_populates="dst_business",sa_relationship_kwargs=dict(foreign_keys="[Business.dst_host_id]"))
    dst_port:int

    delay:Optional[int]=Field(default=None)
    rate:Optional[int]=Field(default=None)
    loss:Optional[float]=Field(default=None)
    disorder:Optional[float]=Field(default=None)
    qos:Optional[int]=Field(default=0,description="8bit，0~255")

class Route(SQLModel, table=True):
    """
    表示每对cpe间各个可用qos类型的路由。
    此表由schedule程序写入。（由于算法未完成，暂定手动填写）
    只需要包含中间的sgw，无需包含入网sgw、出网sgw和出网cpe，这会根据src_cpe和dst_cpe生成
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    
    src_cpe_id:int=Field(foreign_key="cpe.id",description="入网cpe")
    src_cpe:Optional[Cpe] = Relationship(back_populates='route',sa_relationship_kwargs=dict(foreign_keys="[Route.src_cpe_id]"))

    dst_cpe_id:int=Field(foreign_key="cpe.id",description="出网cpe")
    dst_cpe:Optional[Cpe] = Relationship(sa_relationship_kwargs=dict(foreign_keys="[Route.dst_cpe_id]"))

    qos:int=Field(description="8bit，0~255")
    route:str= Field(description="用逗号分割的若干个sgw.id。(不包含cpe)")

sqlite_file=Path(__file__).parent.parent/"database.db"
sqlite_url = f"sqlite:///{sqlite_file}"
def get_engine():
    return create_engine(sqlite_url, echo=False)

def main():
    SQLModel.metadata.create_all(get_engine())

if __name__ == "__main__":
    main()