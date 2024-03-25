"""
1. 所有业务的状态，对应的路由
2. 所有int数据
"""
from pathlib import Path
import sys
import streamlit as st
from sqlmodel import select,Session
import pandas as pd

src=Path(__file__).parent.parent
sys.path.append(str(src))
import orm

image_path=src.parent.parent/'docs'/'实验拓扑.png'
st.subheader("实验网络拓扑")
st.image(str(image_path))
st.write("---")

st.subheader("网络状态")
session=Session(orm.engine)

link_state=session.exec(select(orm.SgwLinkState)).all()
st.write(link_state)

state_df=pd.DataFrame(
    link_state,
    columns=list(orm.SgwLinkState.model_fields.keys())
)

st.dataframe(
    state_df,
    hide_index=True,
)

st.write("---")

st.subheader("各业务路由")

route=session.exec(select(orm.Route)).all()
route_df=pd.DataFrame(
    link_state,
    columns=list(orm.Route.model_fields.keys())
)

