from src import orm

from sqlmodel import select,Session

session=Session(orm.engine)

def get_cpe_by_id(cpe_id:int)->orm.Cpe:
    statement = select(orm.Cpe).where(orm.Cpe.id==cpe_id)
    return session.exec(statement).one()

def get_sgw_locator_by_id(sgw_id:int)->str:
    """
    根据id获取sgw_locator。如果id不存在则返回0。
    locator使用16进制(相比数据库中的表示去掉了中间的冒号)，例如A114F514
    """
    statement = select(orm.Sgw.srv6_locator).where(orm.Sgw.id==sgw_id)
    locator = session.exec(statement).one()
    return locator

def get_forward_sid_by_id(id:int) -> str:
    if id==0:
        locator='0000:0000'
    else:
        locator=get_sgw_locator_by_id(id)
    locator=locator.replace(':','')
    sid='0x'+locator+('0'*24)
    return sid

def get_sgw_locator_by_host_ip(ip:str)->int:
    """
    根据ip地址获取对应主机的入网sgw_locator。
    locator使用16进制(相比数据库中的表示去掉了中间的冒号)，例如A114F514
    """
    statement = select(orm.Host.cpe_id).where(orm.Host.ip==ip)
    cpe_id=session.exec(statement).one()
    statement = select(orm.Cpe.connect_sgw).where(orm.Cpe.id==cpe_id)
    sgw_id=session.exec(statement).one()
    statement = select(orm.Sgw.srv6_locator).where(orm.Sgw.id==sgw_id)
    locator = session.exec(statement).one()
    locator=locator.replace(':','')
    return int(locator,base=16)