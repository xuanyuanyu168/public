#!/bin/bash
#
# Author : hongbin.wang@sap.com
# 
# 20190508 - First version
#Usage : ./CC12-auto_restart_vm.sh hostname BCP_ID
#Please input your password: you_password

echo $* | grep -q -- '-h' 

function show_help {
cat <<EOF

This script is used to check for server unresponsive and restart.

===
Usage : `basename $0` arguments...

Arguments:
  -s  : Server Hostname (IP or FQDN)
  -f  : Batch check needs to restart the server list
  -i  : BCP id
  -h  : Show help

ATTENTION - 
The Server list or Hostname cannot be specified at the same time.

EOF
}

while getopts :s:f:i:h opt
do
	case $opt in
		s)
			export _HOSTNAME_=$OPTARG
			;;
		f)
			export _SERVERLIST_NAME_=$OPTARG
			;;
		i)
			export BCP_ID=$OPTARG
			;;
		h)
			show_help;
			exit 255;
			;;
		\?)
			echo "invalid argument"
			show_help;
			exit 255
			;;
	esac
done

#BCP ID不能为空，如果为空。退出
#BCP_ID有值，不能带特殊符号
[ -z $BCP_ID ] && { echo  "Ticket ID not specified [-i]"; exit 1; } || export BCP_ID=`echo $BCP_ID | sed 's#/#_#g'`

_WORKSPACE_DIR_PATH_=`cd $(dirname $0); pwd -P`
export COMMAND_GOVC=/usr/local/bin/govc
export _RESTART_SERVER_LIST=${_WORKSPACE_DIR_PATH_}/restart-server-list.log
export _HDB_SERVER_LIST=${_WORKSPACE_DIR_PATH_}/HANA-server-list.log
export _RUN_FILE_TMP_=${_WORKSPACE_DIR_PATH_}/FILE.TMP
#Snapshot Name: Year-Month-Day-Hour-BCP ID
#BCP_ID='1930244005'
export current_time=`date +%F-%H`

#定义脚本运行模式:single 还是file
#single：重启单台服务器
#file：批量重启服务器
if [[ -z ${_SERVERLIST_NAME_} ]]; then
	if [[ -z ${_HOSTNAME_} ]]; then
		echo -e "\033[31mThe server List and Hostname cannot both be empty.\033[0m"
		show_help;
		exit 255;
	else 
		echo ${_HOSTNAME_} > ${_RUN_FILE_TMP_}
	fi
else
	if [[ -z ${_HOSTNAME_} ]]; then
		if [[ ! -f ${_SERVERLIST_NAME_} ]] ;then
			echo -e "\033[31m${_SERVERLIST_NAME_} does not exist.\033[0m"
			exit 255
		fi
		`cat ${_SERVERLIST_NAME_} > ${_RUN_FILE_TMP_}`
	else
		echo -e "\033[31mThe Server list or Hostname cannot be specified at the same time.\033[0m"
		show_help;
		exit 255;
	fi
fi

if [ -e ${_RESTART_SERVER_LIST} ];then
	> ${_RESTART_SERVER_LIST}
fi

if [ -e ${_HDB_SERVER_LIST} ];then
	> ${_HDB_SERVER_LIST}
fi

### INPUT login account password ###
export username="$(/usr/bin/id -u -n)"
#read -s -p "Please input your password:" password
password='HFudftdeh@645'
#timeout 10 sshpass -p ${password} ssh -o StrictHostKeyChecking=no ${username}@${_HOSTNAME_VIP_} "echo ${password} | sudo -S /usr/bin/hostname"
#rc_password=$?
#if [[ rc_password -ne 0 ]];then
#        echo "Input password error, Please try again"
#        exit 0
#fi

DISABLE_HANA_SERVER () {
#Determine if it is a DB server
#read -p "Please input your hostname:" hostname 
#hostname:sh3-sfc-b2bx-d1-app-001
#_HOSTNAME_='sh3-tst-b2cx-d1-app-001'
if [[ ${1} =~ -hdb ]];then
	echo -e "\033[31mThe ${1} is a database server,Please don't restart!!!\033[0m"
	echo ${1} >> ${_HDB_SERVER_LIST}
	continue
fi
}

CHECK_VM () {

VM_SNAPSHOT_NAME=${1}-${current_time}-${BCP_ID}

###Define the govc environment variable according to the IDC name###
dc=`echo ${1} | awk -F'-' '{ printf $1}'`

case $dc in
   "ro1" )
       export GOVC_URL='https://ro1-vc-cloud.ycs.io/sdk'
       export GOVC_DATACENTER='RO1-Sankt Leon-Rot'
   ;;
   "sy2" )
       export GOVC_URL='https://sy2-vc-cloud.ycs.io/sdk'
       export GOVC_DATACENTER='SY2-Sydney'
   ;;
   "mo2" )
       export GOVC_URL='https://mo2-vc-cloud.ycs.io/sdk'
       export GOVC_DATACENTER='MO2-MOSCOW'
   ;;
   "sh3" )
       export GOVC_URL='https://sh3-vc-cloud.ycs.io/sdk'
       export GOVC_DATACENTER='SH3-SHANGHAI'
   ;;
   *)
       echo "DC does not exist. Please confirm whether the hostname is correct. The supported DC region are as follows"
       echo "Ro1-Rot"
       echo "SY2-Sydney"
       echo "MO2-Moscow"
       echo "SH3-Shanghai"
       continue
   ;;
esac

export GOVC_INSECURE=1
GOVC_USERNAME=${username}
export GOVC_USERNAME;
export GOVC_PASSWORD=${password}
export GOVC_GUEST_LOGIN='root:*'

}

OS_COMMAND () {
# OS_COMMAND hostname password command
arr_string=($@)
arr_length=${#arr_string[*]}
values_length=`expr $arr_length - 2`

HOSTNAME=${arr_string[0]}
PASSWORD=${arr_string[1]}
COMMAND=${arr_string[@]:2:$arr_length}

timeout 10 sshpass -p ${PASSWORD} ssh -n -o StrictHostKeyChecking=no ${username}@${HOSTNAME} ${COMMAND} 2>/dev/null
}

STOP_VM () {
echo "Stop VM: ${1}"

_HOSTNAME_UUID_=`${COMMAND_GOVC} vm.info ${1} | grep UUID | awk '{ printf $ 2 }'`

${COMMAND_GOVC} vm.power -vm.uuid=${_HOSTNAME_UUID_} -off

#${COMMAND_GOVC} vm.power -vm.ip=${_HOSTNAME_IP_} -off

}

STARTUP_VM () {
echo "Start VM: ${1}"

_HOSTNAME_UUID_=`${COMMAND_GOVC} vm.info ${1} | grep UUID | awk '{ printf $ 2 }'`

${COMMAND_GOVC} vm.power -vm.uuid=${_HOSTNAME_UUID_} -on

#${COMMAND_GOVC} vm.power -vm.ip=${_HOSTNAME_} -on

}

CREATE_VM_SNAPSHOT () {
echo "Creat ${1} snapshot, snapshot name: ${2}" 

${COMMAND_GOVC} snapshot.create -m=false -vm ${1} ${2}

}

CHECK_VM_SNAPSHOT_STATUS () {
echo "Check ${1} snapshot status, snapshot name: ${2}" 
LOOP_COUNT=0
LOOP_COUNT_THRESHOLD=6
#${COMMAND_GOVC} snapshot.tree -vm ${_HOSTNAME_} -D -i

until [ $LOOP_COUNT -ge ${LOOP_COUNT_THRESHOLD} ]
do
	if [[ `${COMMAND_GOVC} snapshot.tree -vm ${1} -D -i | grep ${2} | wc -l` -ge 1 ]] ;then
		LOOP_COUNT=6
	else
		sleep 30
		let LOOP_COUNT++
		if [[ $LOOP_COUNT -eq ${LOOP_COUNT_THRESHOLD} ]] ;then
			echo -e "\033[31mThe snapshot ${1} is not finished.\033[0m"
			continue
		fi
	fi

done

}

CHECK_VM_STATUS () {
echo "Check VM ${1} starting Status"
LOOP_COUNT=0
LOOP_COUNT_THRESHOLD=6

until [ $LOOP_COUNT -ge ${LOOP_COUNT_THRESHOLD} ]
do
	if [[ `OS_COMMAND ${1} $password "/usr/bin/hostname"` ]] ;then
	   LOOP_COUNT=6
	else
		sleep 30
		let LOOP_COUNT++
		if [[ $LOOP_COUNT -eq ${LOOP_COUNT_THRESHOLD} ]] ;then
		   echo -e "\033[31mThe start ${1} is not finished.\033[0m"
		   continue
		fi
	fi

done

}

CHECK_PORT_STATUS () { 
if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "  $0 [IPADDR|DOMAIN] [PORT]"
    echo ""
    echo "Examples:"
    echo "  $0 localhost 80"
    echo "  $0 192.168.1.1 80"
    continue
fi
echo "Check ${1} ${2} port status..."  
 
result=`(sleep 1;) | telnet ${1} ${2} 2>/dev/null | grep Escape | wc -l`
 
if [ $result -eq 1 ]; then
      echo "${1} ${2} is Open."
else
      echo -e "\033[31m${1} ${2} is Closed. Please ckeck ... \033[0m"
fi
}

CHECK_SERVER_STATUS () {
echo "Check ${1} ${2} server status..."

#OS_COMMAND $hostname $password "/usr/bin/hostname" 
SERVER_STATUS=`OS_COMMAND ${1} $password "/usr/bin/ps -ef | grep ${2} | wc -l"`

if [[ ${SERVER_STATUS} -ge 2 ]]; then
	echo "${1} ${2} is active"
else
	echo -e "\033[31m${1} ${2} is failed.\033[0m"
fi
}

CHECK_APPLICATIONS_SERVER_STATUS () {
#hostname:sh3-sfc-b2bx-d1-app-001
echo "check application server status"

APPLICATION=`echo ${1} | awk -F'-' '{ printf $5}'`

case $APPLICATION in
    web)
	CHECK_PORT_STATUS ${1} 80
	CHECK_PORT_STATUS ${1} 81
	CHECK_PORT_STATUS ${1} 443
	CHECK_PORT_STATUS ${1} 444
	CHECK_SERVER_STATUS ${1} httpd
   ;;
   app|adm)
	CHECK_PORT_STATUS ${1} 9001
	CHECK_PORT_STATUS ${1} 9002
	CHECK_SERVER_STATUS ${1} hybris
   ;;
   srch)
       	CHECK_PORT_STATUS ${1} 8983
	CHECK_SERVER_STATUS ${1} solr
   ;;
   dth)
       	CHECK_PORT_STATUS ${1} 9003
	CHECK_PORT_STATUS ${1} 9004
	CHECK_SERVER_STATUS ${1} tomcat
   ;;
   smtp)
       	CHECK_PORT_STATUS ${1} 25
	CHECK_SERVER_STATUS ${1} postfix
   ;;
   sftp)
       	CHECK_PORT_STATUS ${1} 22
	CHECK_SERVER_STATUS ${1} sshd
   ;;
   *)
       echo "application does not exist. The supported application are as follows"
       echo "Web App/Adm Srch Datahub SMTP SFTP"
       continue
   ;;
esac

}


# =====================
###   Main Process  ###
# =====================

echo "========================================================="
echo "=====   CC1.2 check server unresponsive start       ====="
echo "========================================================="

while read _HOSTNAME_
do
	if [ -s ${_RUN_FILE_TMP_} ];then
		DISABLE_HANA_SERVER ${_HOSTNAME_}
		CHECK_VM ${_HOSTNAME_}
		[[ -z `${COMMAND_GOVC} vm.info ${_HOSTNAME_}` ]] && { echo -e "\033[31m${_HOSTNAME_} does not exist.\033[0m"; continue; }
	
		echo "========================================================="
		echo "=====   ${_HOSTNAME_}  restart  starting  ====="
		echo "========================================================="
		FAIL_COUNT=0
		for ((i=1;i<=3;i++));do
		#	if `OS_COMMAND ${_HOSTNAME_} $password "/usr/bin/hostname" > /dev/null`;then
			if `OS_COMMAND ${_HOSTNAME_} $password "/usr/bin/hostaname" > /dev/null`;then
				echo -e "\033[32m${_HOSTNAME_} is alive, don't restart\033[0m"
				#continue
				break
			else
				sleep 10
				let FAIL_COUNT++
			fi
		done

		if [ ${FAIL_COUNT} -eq 3 ];then
			echo ${current_time}  ${_HOSTNAME_} >> ${_RESTART_SERVER_LIST}

			#Creat VM snapshot 
			CREATE_VM_SNAPSHOT ${_HOSTNAME_} $VM_SNAPSHOT_NAME

			#Check vm snapshot status
			CHECK_VM_SNAPSHOT_STATUS ${_HOSTNAME_} $VM_SNAPSHOT_NAME

			if  [[ `${COMMAND_GOVC} vm.info ${_HOSTNAME_} | grep "Power state" | awk '{ printf $3"\n" }'` == poweredOff ]] ;then
				#start vm
				STARTUP_VM ${_HOSTNAME_}
			else
				#stop vm
				STOP_VM ${_HOSTNAME_}
				#start vm
				STARTUP_VM ${_HOSTNAME_}
			fi
			sleep 60

			#check vm start
			CHECK_VM_STATUS ${_HOSTNAME_} 

			#check application server status
			CHECK_APPLICATIONS_SERVER_STATUS ${_HOSTNAME_}
		fi
	else
		echo "The ${_RUN_FILE_TMP_} file is empty and there is no server to check."
	fi
done < ${_RUN_FILE_TMP_}

rm -f ${_RUN_FILE_TMP_}
