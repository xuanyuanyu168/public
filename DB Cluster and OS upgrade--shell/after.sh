#!/bin/sh
_WORKSPACE_DIR_PATH_=`cd $(dirname $0); pwd -P`
_HOSTNAME_VIP_=$1
username=$2
password=$3

sshpass -p ${password} /usr/bin/scp -p ${_WORKSPACE_DIR_PATH_}/post_upgrade.sql ${username}@${_HOSTNAME_VIP_}:/tmp
timeout 10 sshpass -p ${password} ssh -o StrictHostKeyChecking=no ${username}@${_HOSTNAME_VIP_} "sudo -i -u hybadm "/usr/sap/HYB/HDB00/exe/hdbsql -U ADMIN -m -I /tmp/post_upgrade.sql -o /tmp/upgrade_after_configure_alerts_${_HOSTNAME_VIP_}.log""
