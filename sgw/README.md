# INT测试命令

## 端口映射

```C++
181: 
目录：sinet@sinet-181:~/P4/behavioral-model/targets$ 
命令：sudo simple_switch -i 1@ens2f0 -i 2@ens2f2 /home/sinet/P4/behavioral-model/targets/simple_switch/int_srv6/full_project_code.p4

183: 
目录：sinet@sinet-183:~/P4/behavioral-model/targets$ 
命令：sudo simple_switch -i 0@ens1f3 -i 1@ens2f0 -i 2@ens2f2 /home/sinet/P4/behavioral-model/targets/simple_switch/int_srv6/full_project_code.p4

185: 
目录：sinet@sinet-185:~/P4/behavioral-model/targets$ 
命令：sudo simple_switch -i 1@eth1 -i 2@ens2f2 /home/sinet/P4/behavioral-model/targets/simple_switch/int_srv6/full_project_code.p4

187: 
目录：sinet@sinet-187:~/P4/behavioral-model/targets$ 
命令：sudo simple_switch -i 1@eth2 -i 2@ens2f2 /home/sinet/P4/behavioral-model/targets/simple_switch/int_srv6/full_project_code.p4

```


## 插入流表

181: 
目录：sinet@sinet-181:~/P4/behavioral-model/targets/simple_switch$
命令：./runtime_CLI < 182-for_srv6.txt

183: 
目录：sinet@sinet-183:~/P4/behavioral-model/targets/simple_switch$
命令：./runtime_CLI < 184-for_srv6.txt 

185: 
目录：sinet@sinet-185:~/P4/behavioral-model/targets/simple_switch$ 
命令：./runtime_CLI < 185-for_srv6.txt 


187: 
目录：sinet@sinet-187:~/P4/behavioral-model/targets/simple_switch$ 
命令：./runtime_CLI < 187-for_srv6.txt 
