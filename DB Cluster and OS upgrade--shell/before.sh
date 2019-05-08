#!/bin/sh
_WORKSPACE_DIR_PATH_=`cd $(dirname $0); pwd -P`
_HOSTNAME_VIP_=$1
username=$2
password=$3

CPU_CORES=`timeout 10 sshpass -p ${password} ssh -o StrictHostKeyChecking=no ${username}@${_HOSTNAME_VIP_} "sudo cat /proc/cpuinfo| grep "processor"| wc -l"`
echo "This server has a total of ${CPU_CORES} cpus"

sshpass -p ${password} /usr/bin/scp -p ${_WORKSPACE_DIR_PATH_}/${CPU_CORES}.sql ${username}@${_HOSTNAME_VIP_}:/tmp
timeout 10 sshpass -p ${password} ssh -o StrictHostKeyChecking=no ${username}@${_HOSTNAME_VIP_} "sudo -i -u hybadm "/usr/sap/HYB/HDB00/exe/hdbsql -U ADMIN -m -I /tmp/${CPU_CORES}.sql -o /tmp/upgrade_before_configure_alerts_${_HOSTNAME_VIP_}.log""

