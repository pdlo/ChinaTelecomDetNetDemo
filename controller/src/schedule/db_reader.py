from src import orm

from sqlmodel import select,Session


session=Session(orm.engine)

def get_cpe_by_id(cpe_id:int)->orm.Cpe:
    statement = select(orm.Cpe).where(orm.Cpe.id==cpe_id)
    return session.exec(statement).one()

def get_sgw_locator_by_id(sgw_id:int)->int:
    statement = select(orm.Sgw.srv6_locator).where(orm.Sgw.id==sgw_id)
    locator = session.exec(statement).one_or_none()
    if locator is None:
        return 0
    locator=locator.replace(':','')
    return int(locator,base=16)

def get_sgw_locator_by_host_ip(ip:str)->int:
    statement = select(orm.Host.cpe_id).where(orm.Host.ip==ip)
    cpe_id=session.exec(statement).one()
    statement = select(orm.Cpe.connect_sgw).where(orm.Cpe.id==cpe_id)
    sgw_id=session.exec(statement).one()
    statement = select(orm.Sgw.srv6_locator).where(orm.Sgw.id==sgw_id)
    locator = session.exec(statement).one()
    locator=locator.replace(':','')
    return int(locator,base=16)