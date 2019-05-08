#!/bin/bash

_WORKSPACE_DIR_PATH_=`cd $(dirname $0); pwd -P`

username=`id | sed '1{s/[^(]*(//;s/).*//;q}'`
UPGRADE_HANA_VERSION=17
_SCRIPT_FILE_NAME_=`basename $0`
COMMAND_GOVC=/usr/local/bin/govc

if [ $# != 1 ] ;then
    echo "Usage ${_SCRIPT_FILE_NAME_} HOSTNAME"
    echo "  DESCRIPTION:"
    echo "    HOSTNAME - VM name or VM IP address"
    exit 0
else
_HOSTNAME_VIP_=$1
fi

echo "For Example: ./remove_vm_snapshot.sh tmc-p-ma-hdb-vip"

### INPUT login account password ###
read -s -p "Please input your password:" password
timeout 10 sshpass -p ${password} ssh -o StrictHostKeyChecking=no ${username}@${_HOSTNAME_VIP_} "sudo /usr/bin/hostname"
rc_password=$?
if [[ rc_password -ne 0 ]];then
	echo "Input password error,Please try again"
	exit 0
fi


dc=`echo ${_HOSTNAME_} | awk -F'-' '{ printf $3}'`

case $dc in
   "ma" )
       export GOVC_URL='https://10.16.2.94/sdk'
       export GOVC_DATACENTER='MA-Boston'
   ;;
   "fr" )
       export GOVC_URL='https://10.32.2.16/sdk'
       export GOVC_DATACENTER='FR-Frankfurt'
   ;;
esac

export GOVC_INSECURE=1
GOVC_USERNAME='hybrishosting\'${username}
export GOVC_USERNAME;
export GOVC_PASSWORD=${password}
export GOVC_GUEST_LOGIN='root:*'

OS_COMMAND () {
# OS_COMMAND hostname password command
arr_string=($@)
arr_length=${#arr_string[*]}
values_length=`expr $arr_length - 2`

HOSTNAME=${arr_string[0]}
PASSWORD=${arr_string[1]}
COMMAND=${arr_string[@]:2:$arr_length}

timeout 10 sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${username}@${HOSTNAME} ${COMMAND}
}

#check cluster master and define hostname
_HOSTNAME_MASTER_=`OS_COMMAND ${_HOSTNAME_VIP_} $password "/usr/bin/hostname -s"`
echo ""
echo  "Master Server is "${_HOSTNAME_MASTER_}
if [[ `echo ${_HOSTNAME_MASTER_} | awk -F'-' '{print $5}'` -eq 001 ]] ;then	
	_HOSTNAME_SLAVE_=`echo ${_HOSTNAME_VIP_} | awk -F'-' '{ printf $1"-"$2"-"$3"-"$4}'`-002
	_HOSTNAME_MASTER_ALIAS_NAME_=node1
	_HOSTNAME_SLAVE_ALIAS_NAME_=node2
else
	_HOSTNAME_SLAVE_=`echo ${_HOSTNAME_VIP_} | awk -F'-' '{ printf $1"-"$2"-"$3"-"$4}'`-001
	_HOSTNAME_MASTER_ALIAS_NAME_=node2
	_HOSTNAME_SLAVE_ALIAS_NAME_=node1
fi

VM_SNAPSHOT_NAME=${_HOSTNAME_VIP_}_upgrade_to_${UPGRADE_HANA_VERSION}

GET_VM_SNAPSHOT () {

${COMMAND_GOVC} snapshot.tree -vm ${1} -D -i

}

CHECK_VM_SNAPSHOT_STATUS () {
LOOP_COUNT=0
LOOP_COUNT_THRESHOLD=3

until [ $LOOP_COUNT -ge ${LOOP_COUNT_THRESHOLD} ]
do

if [[ `${COMMAND_GOVC} snapshot.tree -vm ${_HOSTNAME_} -D -i | grep ${VM_SNAPSHOT_NAME} | wc -l` -lt 1 ]] ;then
   LOOP_COUNT=3
else
	sleep 30
	let LOOP_COUNT++
	if [[ $LOOP_COUNT -eq ${LOOP_COUNT_THRESHOLD} ]] ;then
	   echo "The snapshot ${VM_SNAPSHOT_NAME} is not finished."
	   exit 0
	fi
fi

done
}

REMOVE_VM_SNAPSHOT () {
if [[ `${COMMAND_GOVC} snapshot.tree -vm ${1} -D -i | grep ${2} | wc -l` -ge 1 ]] ;then
	${COMMAND_GOVC} snapshot.remove -vm ${1} ${2}
else
	echo "The ${2} of the ${1} does not exist."
fi
}

################
##### MAIN #####
################

#Method 1: manually delete the snapshot
#for i in 1 2;do
#	read -p "Please enter the snapshot name you want to restore:" _HOSTNAME_
#	GET_VM_SNAPSHOT ${_HOSTNAME_}
#	read -p "Please enter the snapshot name you want to restore:" VM_SNAPSHOT_NAME
#	if [ ! -n "${_HOSTNAME_}" || ! -n "${VM_SNAPSHOT_NAME}" ] ;then
#		echo "The hostname or snapshot name cannot be empty."
#		exit 0
#	fi
#	REMOVE_VM_SNAPSHOT ${_HOSTNAME_} ${VM_SNAPSHOT_NAME}
#	sleep 60
#	CHECK_VM_SNAPSHOT_STATUS ${_HOSTNAME_}
#	echo ${_HOSTNAME_}" remove snapshot OK"
#done

#Method 2: automatically delete the snapshot
#GET_VM_SNAPSHOT ${_HOSTNAME_MASTER_}
#GET_VM_SNAPSHOT ${_HOSTNAME_SLAVE_}

#Remove VM snapshot
for _HOSTNAME_ in ${_HOSTNAME_MASTER_} ${_HOSTNAME_SLAVE_} ;do
	REMOVE_VM_SNAPSHOT ${_HOSTNAME_} ${VM_SNAPSHOT_NAME}
done

#check vm snapshot status
CHECK_VM_SNAPSHOT_STATUS ${_HOSTNAME_MASTER_}
echo ${_HOSTNAME_MASTER_}" Remove snapshot OK"
CHECK_VM_SNAPSHOT_STATUS ${_HOSTNAME_SLAVE_}
echo ${_HOSTNAME_SLAVE_}" Remove snapshot OK"


