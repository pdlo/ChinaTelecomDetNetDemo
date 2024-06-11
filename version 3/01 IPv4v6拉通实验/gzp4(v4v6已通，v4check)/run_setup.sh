#! /bin/bash
export SDE=/root/bf-sde-9.1.0
export SDE_INSTALL=$SDE/install
export PATH=$SDE_INSTALL/bin:$PATH
$SDE_INSTALL/bin/bf_kdrv_mod_load $SDE_INSTALL
/root/bf-sde-9.1.0/run_bfshell.sh -b /root/chinatelecom/simple_ipv6_v2/setup.py
