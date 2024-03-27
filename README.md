## 0328 演示系统移植和启动方式 by WXY
以下所有命令的工作目录都是/controller。
代码基于python3。
### 安装
```
sudo apt install pipx
pipx install pdm
pdm venv create
pdm install
```
### 配置
复制example_config.toml，改名为config.toml
把其中的账号密码改成真实值（因为不能把它放到github上）

### 启动
```bash
streamlit ./src/app/main.py
```



## cpe启动过程 by GZC

目前cpe为tofino交换机151，152，153。

**以下操作都在my_p4/srv6/目录下执行。**

### 编译

```
bash compile.sh
```

(p4程序不改变，编译命令只需运行一次即可)

### 开启bfshell和交换机端口

```
bash run.sh 
```

这个脚本包含开启bfshell和插入端口，完成后将会话隐藏在后端，保持交换机一直开启。

### 执行hping3脚本

**脚本文件在/home/sinet/目录下，名称为hping3_script.sh。流表下发成功后执行命令。**

```
bash hping3_script.sh <源端口> <目的端口> <目的IP>
```

执行后输出rtt往返时延。



## 地址设置规定(暂定)

### 管理ssh地址
1. 实验拓扑中所有设备都有一个设备号，150~190
2. 设备号与ssh地址有关，安全起见，具体请询问组内人员

### srv6 sid
1. SRv6 SID是一个128bit的值，为IPv6地址形式，由Locator、Function和Arguments三部分组成。
1. 我们将前32位作为locator，标记一个srv6转发结点，即sgw。
1. 在数据库和代码中，使用类似A114:0514的格式存储一个locator，即8个0~A，中间用冒号分割
1. 默认使用设备号，例如181的locator就是0000:0181

### 终端 ipv4
1. cpe只进行ipv4转发，不进行mac转发；一个终端自己组成一个子网。
1. ipv4地址设置为 【10.交换机设备号.终端设备号.2/24】
1. 对于路由，对于所有cpe，把【10.CPE设备号.0.0/8】路由到交换机上，网关是【10.交换机设备号.终端设备号.1/24】

```bash
#例如交换机153连接终端162的网卡eth1
sudo ip addr add 10.153.162.2/24 dev eth1
sudo ip route add 10.0.0.0/8 via 10.153.162.1 dev eth1
```

## 代码结构
包括4部分代码，交换机(cpe)，交换机(sgw)，控制器(调度)，控制器(int)

### 交换机(cpe)
1. 使用tofino    
1. 对于终端发来的数据包，按照源ip和目的ip匹配，添加相应的srv6头部
    - 为了使终端能顺利发送数据，对终端进行arp欺骗
    - 后续需要增加源端口号和目的端口号
1. 对于sgw发来的数据包，按照ipv4转发。
    - 为了使终端能顺利接收数据，要去掉除ipv6头部

### 交换机(sgw)
1. 使用bmv2，绑定实体网卡
1. 如果数据包有srv6头，进行srv6转发
1. 如果是int数据包，收集相应的信息
1. 如果数据包没有srv6头，按照ipv6转发（暂时用不到，后续再讨论具体实现）
1. 这一部分仅用于demo，未来会使用电信提供的设备（支持srv6转发，但遥测支持情况不确定）

### 控制器(调度)
1. 建立数据库，存储sgw信息，每一跳的网络状态数据，以及业务需求
1. 每隔一段时间，为所有业务计算路由，向cpe下发相应的流表

### 控制器(int)
1. 发送int数据包
1. 接收并处理int数据包，计算每一跳的网络状态数据，存入数据库
