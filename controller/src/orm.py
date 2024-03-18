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
    console_ip:str = Field(description="用于ssh的ipv4地址，使用类似10.0.2.1的格式")
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
    console_ip:str = Field(description="用于ssh的ipv4地址，使用类似10.0.2.1的格式")
    connect_sgw:int = Field(foreign_key="sgw.id")

class Business(SQLModel, table=True):
    """
    id被作为外键，此表中数据不应该删除。希望删除业务时请把enabled置为False。
    此表暂定是手动填写的，后续业务可能改变。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    src_ip:str = Field(description="源主机的ip地址")
    src_port:str = Field(description="源主机的端口号")
    src_cpe_id:int = Field(foreign_key="cpe.id",description="入网cpe")
    dst_ip:str = Field(description="目的主机的ip地址")
    dst_port:str = Field(description="目的主机的端口号")
    dst_cpe_id:int = Field(foreign_key="cpe.id",description="出网cpe")
    delay:Optional[int]=Field(default=None)
    rate:Optional[int]=Field(default=None)
    loss:Optional[float]=Field(default=None)
    disorder:Optional[float]=Field(default=None)
    create_datetime:Optional[datetime]=Field(default=None)
    enabled:bool

class Route(SQLModel, table=True):
    """
    此表由schedule程序写入。仅用于记录和展示。
    似乎不能保证和当前bmv2路由的一致性。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    business_id:int = Field(foreign_key="business.id")
    create_datetime:datetime
    route:str = Field(description="逗号分割的若干sgw_id")

sqlite_file=Path(__file__).parent.parent/"database.db"
sqlite_url = f"sqlite:///{sqlite_file}"
engine = create_engine(sqlite_url, echo=False)

def main():
    SQLModel.metadata.create_all(engine)

if __name__ == "__main__":
    main()