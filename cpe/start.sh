#TODO
##编译（初始环境编译）：
export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

#加载bf驱动
#$SDE_INSTALL/bin/bf_kdrv_mod_load $SDE_INSTALL
cd $SDE/pkgsrc/p4-build
./autogen.sh

#程序编译
$SDE/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c --prefix=$SDE_INSTALL \
--bindir=$SDE_INSTALL/bin \
P4_NAME=srv6 \
P4_PATH=/root/my_p4/srv6/srv6.p4 \
P4_VERSION=p4-16 P4_ARCHITECTURE=tna \
LDFLAGS="-L$SDE_INSTALL/lib" \
--enable-thrift

make
make install

#/root/bf-sde-9.1.0/run_switchd.sh -p srv6