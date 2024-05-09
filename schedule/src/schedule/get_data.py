from itertools import permutations
import typing
from sqlmodel import select,col,Session
from sqlalchemy import func
import pandas as pd
from collections.abc import Collection

from src.orm import *

def get_all_src_dst_paths(session:Session)->dict[str,dict[int,NetPath]]:
    """
    解析path表，根据所有path，构造如下字典结构：
    {
        "src_1-dst_1":{
            path_id_1:path,
            path_id_2:path,
            ...
        },
        "src_2-dst_2":{
            ...
        },
        ...
    }
    """
    nodes = session.exec(select(MRN)).all()
    paths={}
    for i,j in permutations(nodes):
        this_paths=session.exec(select(NetPath).where(NetPath.src_mrn==i and NetPath.dst_mrn==j)).all()
        if this_paths:
            paths[f"{i.name}->{j.name}"]={path.id:path for path in this_paths}
    return paths

def get_delay(path_ids:Collection[int],session:Session):
    statement = (
        select(NetPathState.path_id,NetPathState.delay,func.max(NetPathState.create_datetime))
        .where(col(NetPathState.path_id).in_(path_ids))
        .group_by(col(NetPathState.path_id))
    )
    data = session.exec(statement)
    def _to_row():
        for i in data:
            yield {
                'path_id':i.path_id, # type: ignore
                'path_delay':i.delay # type: ignore
            }
    return pd.DataFrame(_to_row())

def get_bandwidth(paths:typing.Sequence,session:Session):
    ...#TODO

if __name__ == '__main__':
    with get_session() as session:
        paths=get_all_src_dst_paths(session)
        for i,j in paths.items():
            print(get_delay(j.keys(),session))

