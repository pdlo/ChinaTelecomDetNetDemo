## 先杀进程
bash ./shutdown.sh

##编译（初始环境编译）：
export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH

#这里153可以换成任意会话名
screen -S 153 -dm bash -c '/root/bf-sde-9.1.0/run_switchd.sh -p srv6 && exit'
#要用command.txt文件
/root/bf-sde-9.1.0/run_bfshell.sh -f /root/my_p4/srv6/command.txt

#/root/bf-sde-9.1.0/run_switchd.sh -p srv6