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

echo "For Example: ./revert_vm_snapshot.sh tmc-p-ma-hdb-vip"


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

REVERT_VM_SNAPSHOT () {
if [[ `${COMMAND_GOVC} snapshot.tree -vm ${1} -D -i | grep ${2} | wc -l` -ge 1 ]] ;then
	${COMMAND_GOVC} snapshot.revert -vm ${1} ${2}
else
	echo "The ${2} of the ${1} does not exist."
fi

}

STARTUP_VM () {

_HOSTNAME_UUID_=`${COMMAND_GOVC} vm.info ${1} | grep UUID | awk '{ printf $ 2 }'`

${COMMAND_GOVC} vm.power -vm.uuid=${_HOSTNAME_UUID_} -on

}


################
##### MAIN #####
################

#Method 1: manually revert the snapshot
#for i in 1 2;do
#	read -p "Please enter the snapshot name you want to restore:" _HOSTNAME_
#	GET_VM_SNAPSHOT ${_HOSTNAME_}
#	read -p "Please enter the snapshot name you want to restore:" VM_SNAPSHOT_NAME
#	if [ ! -n "${_HOSTNAME_}" || ! -n "${VM_SNAPSHOT_NAME}" ] ;then
#		echo "The hostname or snapshot name cannot be empty."
#		exit 0
#	fi
#	REVERT_VM_SNAPSHOT ${_HOSTNAME_} ${VM_SNAPSHOT_NAME}
#	sleep 60
#	if [[ `${COMMAND_GOVC} vm.info ${_HOSTNAME_} | grep "Power state" | awk '{ printf $3"\n" }'` == poweredOff ]] ;then
#		STARTUP_VM ${_HOSTNAME_}
#	fi
#	echo ${_HOSTNAME_}" is startup."
#done


#Method 2: automatically revert the snapshot
#GET_VM_SNAPSHOT ${_HOSTNAME_MASTER_}
#GET_VM_SNAPSHOT ${_HOSTNAME_SLAVE_}

#Revert VM snapshot
for _HOSTNAME_ in ${_HOSTNAME_MASTER_} ${_HOSTNAME_SLAVE_} ;do
	REVERT_VM_SNAPSHOT ${_HOSTNAME_} ${VM_SNAPSHOT_NAME}
	if [[ `${COMMAND_GOVC} vm.info ${_HOSTNAME_} | grep "Power state" | awk '{ printf $3"\n" }'` == poweredOff ]] ;then
		STARTUP_VM ${_HOSTNAME_}
	fi
	echo ${_HOSTNAME_}" is startup."
	sleep 30
done





