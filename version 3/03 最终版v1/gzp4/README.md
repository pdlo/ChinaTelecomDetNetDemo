
## 编译

export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
cd $SDE/pkgsrc/p4-build
./autogen.sh

$SDE/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c --prefix=$SDE_INSTALL \
--bindir=$SDE_INSTALL/bin \
P4_NAME=sinet_v1 \
P4_PATH=/root/chinatelecom/sinet_v1/sinet_v1.p4 \
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

cd ~/chinatelecom/sinet_v1
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

cd ~/chinatelecom/sinet_v1
chmod +777 ./*
./run_setup.sh

