"""
包含各个表的orm。
运行此文件将会建表。
"""
from typing import Optional
from sqlmodel import Field, SQLModel, create_engine, Relationship,Session
from pathlib import Path
from datetime import datetime
from ipaddress import IPv4Address
from pydantic_extra_types.mac_address import MacAddress

__all__=['MRN','NetPath','NetPathState','get_session']
class MRN(SQLModel, table=True):
    """
    所有多路径选路结点（MultiNetPath Routing Node）
    此表id被作为外键，不应该删除数据。
    此表是手动根据网络配置填写的。
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    ssh_ip:IPv4Address
    ssh_port:int 

class NetPath(SQLModel, table=True):
    """
    表示每条路径
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    
    src_mrn_id: int = Field(foreign_key="mrn.id")
    src_mrn: Optional[MRN] = Relationship(sa_relationship_kwargs=dict(foreign_keys="[NetPath.src_mrn_id]"))
    
    dst_mrn_id: int = Field(foreign_key="mrn.id")
    dst_mrn: Optional[MRN] = Relationship(sa_relationship_kwargs=dict(foreign_keys="[NetPath.dst_mrn_id]"))
    
    route:str= Field(description="用逗号分割的若干个sid，最多5个")
    

class NetPathState(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)

    path_id:int = Field(foreign_key="netpath.id")
    path:Optional[NetPath]=Relationship()

    create_datetime:datetime
    delay:Optional[int]=Field(default=None)

sqlite_file=Path(__file__).parent.parent/"database.db"
sqlite_url = f"sqlite:///{sqlite_file}"


# echo=True
echo=False
engine = create_engine(sqlite_url,echo=echo)

def get_session():
    return  Session(engine)

def main():
    SQLModel.metadata.create_all(engine)

if __name__ == "__main__":
    main()