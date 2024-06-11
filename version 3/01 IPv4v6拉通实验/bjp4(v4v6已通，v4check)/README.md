
scp ~/p4bj/* root@172.27.15.2:~/chinatelecom/simple_ipv6
密码：onl

scp ~/send.pcap root@172.29.83.74:~/
密码：Gsta@2706

scp ~/receive.pcap root@172.29.83.74:~/
密码：Gsta@2706

ssh root@172.27.15.2
密码：onl

ssh bjtu-bj1@172.27.15.3
密码：bjtungirc

ssh bjtu-bj3@172.27.15.4
密码：bjtungirc

sudo route add -net 172.29.89.112/28 gw 172.27.15.129 metric 1 dev enp3s0f1
sudo route add -net 198.18.204.118/24 gw 172.27.15.129 metric 1 dev enp3s0f1

sudo route del -host 198.18.204.118
sudo route del -net 198.18.204.118 netmask 255.255.255.0 gw 172.27.15.129

sudo tcpdump -i enp3s0f1 -w test.pcap
sudo tcpdump -i enp3s0f1
sudo tcpdump -i enp3s0f1 host 198.18.204.113 and 172.27.15.3 抓取两个ip之间的通信数据包

mount /dev/sdb4 /mnt/usb
umount /dev/sdb4 /mnt/usb

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

screen -ls

## 运行p4
screen -S run_p4

cd ~/chinatelecom/simple_ipv6_v2
chmod +777 ./*
./run_p4.sh

## 激活端口

ucli
pm port-add 9/0 10g none
pm port-add 13/0 10g none
pm port-add 33/0 10g none
pm port-enb 9/0
pm port-enb 13/0
pm port-enb 33/0
pm show

## 退出界面
Ctrl+A+D
## 进入界面
screen -r run_p4

## 下发流表

screen -S run_setup

cd ~/chinatelecom/simple_ipv6_v2
chmod +777 ./*
./run_setup.sh

