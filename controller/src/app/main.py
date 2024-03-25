"""
1. 所有业务的状态，对应的路由
2. 所有int数据
"""
from pathlib import Path
import sys
import streamlit as st
from sqlmodel import select,Session
import pandas as pd

root=Path(__file__).parent.parent.parent
print(root)
sys.path.append(str(root))

from src import orm
from src.app.read_db import get_link_latest_states_iter,get_routes_iter

if "config_seted" not in st.session_state:
    st.session_state["config_seted"]=True
    st.set_page_config(
        page_title="页面标题待定",
        layout="wide",
        initial_sidebar_state="expanded",
    )


image_path=root.parent/'docs'/'实验拓扑.png'
st.subheader("实验网络拓扑")
st.image(str(image_path))
st.write("---")

col1,col2=st.columns([4,6])

with col1:
    st.subheader("网络状态")
    state_df=pd.DataFrame(get_link_latest_states_iter())

    st.dataframe(
        state_df,
        hide_index=True,
        use_container_width=True
    )

with col2:
    st.subheader("路由")
    route_df=pd.DataFrame(get_routes_iter())
    st.dataframe(
        route_df,
        hide_index=True,
        use_container_width=True
    )

st.write("---")
