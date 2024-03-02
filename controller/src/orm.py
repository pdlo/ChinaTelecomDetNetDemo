"""
包含各个表的orm
运行此文件建表
"""

from typing import Optional
from sqlmodel import Field, SQLModel, create_engine,Session,select
from pathlib import Path

class Switch(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    srv6_locator:str #使用类似2001:0db8:86a3:08d3的格式

class Connection(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    switch_id_1:int
    interface_1:int
    switch_id_2:int
    interface_2:int
    delay:Optional[int]
    rate:Optional[int]
    loss:Optional[float]
    
class Business(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    src_switch_id:int
    src_interface:int
    dst_switch_id_2:int
    src_interface:int
    delay:Optional[int]
    rate:Optional[int]
    loss:Optional[float]
    disorder:Optional[float]

sqlite_file=Path(__file__).parent.parent/"database.db"
sqlite_url = f"sqlite:///{sqlite_file}"
engine = create_engine(sqlite_url, echo=False)

def main():
    SQLModel.metadata.create_all(engine)

if __name__ == "__main__":
    main()