## 各部分说明
### schedule
#### 进度
完成基本框架，下发流表代码已完成但未合并，读取计数器代码未完成
#### 移植
1. 安装环境，建表
```bash
sudo apt install pipx
pipx install pdm
cd schedule
pdm install
pdm run create_table
```
2. 根据example_config.toml编写config.toml
3. 运行
```bash
pdm run start
```
