## 先杀进程
bash ./shutdown.sh

##编译（初始环境编译）：
export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH


/root/bf-sde-9.1.0/run_switchd.sh -p srv6