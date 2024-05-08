
## 编译

export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH


cd $SDE/pkgsrc/p4-build
./autogen.sh

$SDE/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c --prefix=$SDE_INSTALL \
--bindir=$SDE_INSTALL/bin \
P4_NAME=srv6int_v6 \
P4_PATH=/root/my_p4/xzh/srv6int_v6/srv6int_v6.p4 \
P4_VERSION=p4-16 P4_ARCHITECTURE=tna \
LDFLAGS="-L$SDE_INSTALL/lib" \
--enable-thrift

make

make install

## 检查进程

ps -ax | grep switchd
sudo kill <proces id>

## 运行p4

cd ~/my_p4/xzh/srv6int_v6
chmod +777 ./*
./run_p4.sh

## 下发流表

cd ~/my_p4/xzh/srv6int_v6
chmod +777 ./*
./run_setup.sh

## 激活端口

ucli
pm port-add 25/0 10g none
pm port-add 27/0 10g none
pm port-add 29/0 10g none
pm port-add 31/0 10g none
pm port-enb 25/0
pm port-enb 27/0
pm port-enb 29/0
pm port-enb 31/0
pm show
