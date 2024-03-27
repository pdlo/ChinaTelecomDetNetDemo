import streamlit as st

from src.orm import get_engine as get_engine_original

"""
因为streamlit反复运行脚本的特性，用这种方式拦截对engine的重复创建，始终使用一个engine
"""

@st.cache_resource
def get_engine():
    print("创建数据处理engine")
    return get_engine_original()
