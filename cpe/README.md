## 运行流程
1. install.sh 疑似断电重启后，需要运行一次，配置某个系统设置
2. compile.sh 修改代码后，重新编译p4代码
3. run.sh 启动p4程序
    1. 会调用shutdown.sh 杀死现有的p4
4. run_setup.sh 添加流表
5. open_shell.sh 连接到bft cli

## 使用程序添加流表的方案
1. 由于缺少文档，尝试通过追溯run_setup.sh找到添加流表的其他方案。但最终发现添加流表通过bfshell，这是一个二进制文件而非脚本。
1. 目前唯一已知的添加流表方式是合成python文件，然后通过/root/bf-sde-9.1.0/run_bfshell.sh -b xxx.py添加。

## 流表

1. 根据目的ip，源ip，tcp出端口匹配流量等级。
1. 根据目的ip，源ip，流量等级执行不同srv6路径。