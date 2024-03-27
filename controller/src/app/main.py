"""
1. 所有业务的状态，对应的路由
2. 所有int数据
"""
import streamlit as st
from sqlmodel import select,Session
import pandas as pd
from datetime import datetime,timedelta
from pathlib import Path
import sys

root=Path(__file__).parent.parent.parent
sys.path.append(str(root))

from src.app.read_db import get_link_latest_states_iter,get_all_route,get_bussiness,add_business

page_title="基于业务感知和控制的确定性网络关键技术研究与验证项目实验与演示系统"

if "config_seted" not in st.session_state:
    st.session_state["config_seted"]=True
    st.set_page_config(
        page_title=page_title,
        layout="wide",
        initial_sidebar_state="expanded",
    )

# st.header(page_title)

st.write("---")

col1,col2,col3=st.columns([4,3,3])

with col1:
    st.subheader("实验网络拓扑")
    image_path=root.parent/'docs'/'实验拓扑.png'
    st.image(str(image_path))

with col2:
    st.subheader("网络状态")
    int_table_container=st.empty()

with col3:
    st.subheader("路由")
    route_df=pd.DataFrame(get_all_route())
    st.dataframe(
        route_df,
        hide_index=True,
        use_container_width=True,
    )


col1,col2=st.columns([5,5])
with col1:
    st.subheader("业务")
    bussiness_container=st.empty()

with col2:
    with st.form("添加业务(部分功能尚未实现)"):
        inner_col1,inner_col2 = st.columns(2)
        with inner_col1:
            src_name=st.text_input("主机1",value='162')
            dst_name=st.text_input("主机2",value='166')
            
        with inner_col2:
            src_port=st.number_input("主机1端口",value=1234,step=1)
            dst_port=st.number_input("主机2端口",value=1234,step=1)

        st.write('---')

        inner_col1,inner_col2 = st.columns(2)
        with inner_col1:
            delay_to_qos={
                '0 ~ 20':(2,10),
                '20 ~ 40':(1,40),
                '40 ~ 60':(0,60),
                '无限制':(0,0)
            }
            need = st.selectbox("时延需求(ms)",delay_to_qos.keys(),3)
            qos,delay=(0,0) if need is None else delay_to_qos[need]
            st.write(qos,delay)
            assert isinstance(qos,int)
            st.number_input("时延需求(μs)",step=1)
            rate=st.number_input("带宽需求(byte/s)",disabled=True,step=1)
        with inner_col2:
            loss=st.number_input("丢包率需求(%)",disabled=True)
            disorder=st.number_input("乱序需求(%)",disabled=True)

        if st.form_submit_button("添加/修改"):
            bussiness_container.warning("流表下发中，请稍候。")
            int_table_container.warning("流表下发中，请稍候。")
            try:
                add_business(
                    qos,
                    src_name,
                    int(src_port),
                    dst_name,
                    int(dst_port),
                    delay,
                    int(rate),
                    loss,
                    disorder
                )
            except Exception as e:
                # st.error(str(e))
                raise e


business_df=pd.DataFrame(get_bussiness())
bussiness_container.dataframe(
    business_df,
    hide_index=True,
    use_container_width=True,
)


last_schedule_time=datetime.min
while True:
    now_time=datetime.now()
    if now_time-last_schedule_time < timedelta(seconds=5):
        continue
    last_schedule_time=now_time
    container = int_table_container.container()
    with container:
        st.write(datetime.now().strftime("最后更新于 %Y.%m.%d %H:%M:%S"))
        state_df=pd.DataFrame(get_link_latest_states_iter())
        st.dataframe(
            state_df,
            hide_index=True,
            use_container_width=True
        )