"""
负责进行页面布局，接收用户输入
"""
import streamlit as st
from datetime import datetime,timedelta
from pathlib import Path
import sys
from typing import Tuple,Union,Dict

root=Path(__file__).parent.parent.parent
sys.path.append(str(root))

from src.app.read_db import get_latest_link_states,get_all_routes,get_bussiness,add_business
from src.app.utils import logger

page_title="基于业务感知和控制的确定性网络关键技术研究与验证项目实验与演示系统"


if "config_seted" not in st.session_state:
    st.session_state["config_seted"]=True
    st.set_page_config(
        page_title=page_title,
    )

st.subheader("实验网络拓扑")
topo_empty=st.empty()
topo_empty.warning("加载中")

st.subheader("网络状态")
state_empty=st.empty()
state_empty.warning("加载中")

st.subheader("路由")
route_empty=st.empty()
route_empty.warning("加载中")

st.subheader('业务编辑')
add_business_empty=st.empty()
add_business_empty.warning("加载中")

st.subheader("当前业务")
show_business_empty=st.empty()
show_business_empty.warning("加载中")

with topo_empty:
    image_path=root.parent/'docs'/'实验拓扑.png'
    st.image(str(image_path))

with route_empty:
    route_df=get_all_routes()
    st.dataframe(
        route_df,
        hide_index=True,
        use_container_width=True,
    )

with add_business_empty:
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
            delay_to_qos:Dict[str,Tuple[int,Union[int,None]]]={
                '0 ~ 20':(2,20),
                '20 ~ 40':(1,40),
                '40 ~ 60':(0,60),
                '无限制':(0,None)
            }
            need = st.selectbox("时延需求(ms)",delay_to_qos.keys(),3)
            if need is None:
                need='无限制'
            qos,delay=delay_to_qos[need]
            rate=st.number_input("带宽需求(byte/s)",disabled=True,step=1)
            rate=int(rate)
        with inner_col2:
            loss=st.number_input("丢包率需求(%)",disabled=True)
            disorder=st.number_input("乱序需求(%)",disabled=True)

        if st.form_submit_button("添加/修改"):
            try:
                add_business(
                    qos,
                    src_name,
                    int(src_port),
                    dst_name,
                    int(dst_port),
                    delay,
                    rate,
                    loss,
                    disorder
                )
            except Exception as e:
                st.error(str(e))
                # raise e

with show_business_empty:
    business_df=get_bussiness()
    st.dataframe(
        business_df,
        hide_index=True,
        use_container_width=True,height=400
    )
    
last_schedule_time=datetime.min

while True:
    now_time=datetime.now()
    if now_time-last_schedule_time < timedelta(seconds=5):
        continue
    last_schedule_time=now_time
    with state_empty.container():
        st.write(datetime.now().strftime("最后更新于 %Y.%m.%d %H:%M:%S"))
        state_df=get_latest_link_states()
        st.dataframe(
            state_df,
            hide_index=True,
            use_container_width=True
        )