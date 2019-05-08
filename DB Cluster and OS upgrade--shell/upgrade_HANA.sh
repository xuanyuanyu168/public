#!/bin/bash
if [[ `uname -av | grep "3.10.0-693" | wc -l` -eq 1 ]] ;then
cd /usr/sap/HYB/home/API
./upgrade.sh 17
else
echo $hostname
echo "Kernel version error."
fi
