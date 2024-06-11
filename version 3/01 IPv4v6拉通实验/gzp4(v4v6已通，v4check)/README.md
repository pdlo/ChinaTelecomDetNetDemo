
scp ~/p4gz/* root@172.29.90.3:~/chinatelecom/simple_ipv6
密码：onl

ssh root@172.29.90.3
密码：onl

ssh gsta@172.29.90.7
密码：Gsta@123

ssh gsta@172.29.90.8
密码：Gsta@123

sudo tcpdump -i ens192 -w test.pcap

sudo ip addr add 172.29.89.113/28 dev ens192 broadcast 172.29.89.127
sudo ip addr del 172.29.89.113/28 dev ens192
sudo route add -net 172.27.15.128/25 gw 172.29.89.126 metric 1 dev ens192
sudo route add -net 198.18.203.0/24 gw 172.29.89.126 metric 1 dev ens192
sudo ip -6 addr add 2402:8800:fffe:113::71/120 dev ens192
sudo ip -6 route add 2402:8800:fffe:10e::1060:1/112 via 2402:8800:fffe:113::1


scp ./test.pcap root@172.29.83.74:~/

scp ./rrr.pcap root@172.29.83.74:~/

## 编译

export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
cd $SDE/pkgsrc/p4-build
./autogen.sh

$SDE/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c --prefix=$SDE_INSTALL \
--bindir=$SDE_INSTALL/bin \
P4_NAME=simple_ipv6_v2 \
P4_PATH=/root/chinatelecom/simple_ipv6_v2/simple_ipv6_v2.p4 \
P4_VERSION=p4-16 P4_ARCHITECTURE=tna \
LDFLAGS="-L$SDE_INSTALL/lib" \
--enable-thrift

make

make install

## 检查进程

ps -ax | grep switchd
sudo kill <proces id>

## 运行p4

cd ~/chinatelecom/simple_ipv6_v2
chmod +777 ./*
./run_p4.sh

## 下发流表

cd ~/chinatelecom/simple_ipv6_v2
chmod +777 ./*
./run_setup.sh

## 激活端口

ucli
pm port-add 9/0 10g none
pm port-add 13/0 10g none
pm port-add 33/0 10g none
pm port-enb 9/0
pm port-enb 13/0
pm port-enb 33/0
pm show
