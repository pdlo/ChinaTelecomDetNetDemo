#!/bin/bash

for ((i=1; i<=15; i++))
do
    sudo hping3 -s "$1" -p "$2" "$3" -c 1 2>&1 | grep -e "rtt"
done
#$1为源端口，$2为目的端口，$3目的ip。
#while true; do
#    sudo hping3 -s "$1" -p "$2" "$3" -c 1 2>&1 | grep -e "rtt"
#done
