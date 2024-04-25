## 1.网络拓扑

![image-20240423103509875](C:\Users\zhiqiang\AppData\Roaming\Typora\typora-user-images\image-20240423103509875.png)

## 2. p4代码编译

2.1 配置环境变量

```
##编译（初始环境编译）：
export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

#加载bf驱动（断电重启后需要重新加载）
#$SDE_INSTALL/bin/bf_kdrv_mod_load $SDE_INSTALL 

cd $SDE/pkgsrc/p4-build
./autogen.sh
```

2.2  编译

```
#int_edge和int_middle选择其一
#int_edge
$SDE/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c --prefix=$SDE_INSTALL \
--bindir=$SDE_INSTALL/bin \
P4_NAME=int_edge \
P4_PATH=/root/my_p4/int/int_edge/int_edge.p4 \
P4_VERSION=p4-16 P4_ARCHITECTURE=tna \
LDFLAGS="-L$SDE_INSTALL/lib" \
--enable-thrift

#int_middle
$SDE/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c --prefix=$SDE_INSTALL \
--bindir=$SDE_INSTALL/bin \
P4_NAME=int_middle \
P4_PATH=/root/my_p4/int/int_middle/int_middle.p4 \
P4_VERSION=p4-16 P4_ARCHITECTURE=tna \
LDFLAGS="-L$SDE_INSTALL/lib" \
--enable-thrift


#最后再make
make
make install
```

## 3. 运行p4

```
#运行程序选择其一
#int_edge
/root/bf-sde-9.1.0/run_switchd.sh -p int_edge

#int_middle
/root/bf-sde-9.1.0/run_switchd.sh -p int_middle

#bfrt_python查看编译文件
#使用指令bfrt会进入到bfrt目录下
bfrt
#再选择对应的P4文件
int_edge
#进入p4的主函数Pipe
pipe
#选择对应的函数块
Ingress
#再查看对应的表
select_traffic_class
#返回上一级目录使用..
#退出 bfrt_python 使用exit
```

### 4.下发流表

下发流表采用run_setup.sh脚本,下发前检查是否有其它进程正在使用

```
#检查进程
ps -ax | grep switchd
sudo kill <proces id>

#下发流表
bash run_setup.sh
```

### 5. 激活端口

```
##编译（初始环境编译）：
export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

#int_edge
/root/bf-sde-9.1.0/run_bfshell.sh -f /root/my_p4/int/int_edge/command.txt

#int_middle
/root/bf-sde-9.1.0/run_bfshell.sh -f /root/my_p4/int/int_middle/command.txt
```

### 6.182与188网关配置

```
188
21.158.188.2   网关21.158.188.1
mac 00:00:00:00:00:00
sudo ip addr add 21.158.188.2/24 dev ens1f2
sudo ip route add 21.0.0.0/8 via 21.158.188.1 dev ens1f2


182
21.156.182.2   网关21.156.182.1
mac 00:00:00:00:00:00
sudo ip addr add 21.156.182.2/24 dev ens1f2
sudo ip route add 21.0.0.0/8 via 21.156.182.1 dev ens1f2
```



#### 6.远程登录的账号密码

账号：root

密码：onl

