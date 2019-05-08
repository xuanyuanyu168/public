#!/bin/bash
#
# Author : 541092792@qq.com
# 
# 20180503 - First version 
# 20180603 - Second version 
# 20180803 - Third version 
#Usage ./main.sh hostname-vip
#For Example: ./main.sh h21-p-ma-hdb-vip

_WORKSPACE_DIR_PATH_=`cd $(dirname $0); pwd -P`
_SCRIPT_FILE_NAME_=`basename $0`
UPGRADE_OS_VERSION=7.4
KERNEL_VERSION=3.10.0-693.43
UPGRADE_HANA_VERSION=17
COMMAND_GOVC=/usr/local/bin/govc
UPGRADE_OS_KERNEL_SCRIPT=upgrade_os_kernel.sh
UPGRADE_HANA_SCRIPT=upgrade_HANA.sh
HANA_OWNER=hybadm

username=`id | sed '1{s/[^(]*(//;s/).*//;q}'`
### INPUT login account password ###
#read -p "Please input your username:" username
read -s -p "Please input your password:" password
timeout 10 sshpass -p ${password} ssh -o StrictHostKeyChecking=no ${username}@${_HOSTNAME_VIP_} "sudo /usr/bin/hostname"
rc_password=$?
if [[ rc_password -ne 0 ]];then
        echo "Input password error, Please try again"
        exit 0
fi

#_HOSTNAME_=$1
if [ $# != 1 ] ;then
    echo "Usage ${_SCRIPT_FILE_NAME_} HOSTNAME"
    echo "  DESCRIPTION:"
    echo "  HOSTNAME - VM name or VM IP address"
    exit 0
else
_HOSTNAME_VIP_=$1
fi
    echo "  For Example: ./main.sh tmc-p-ma-hdb-vip"
#_HOSTNAME_IP_=`ping ${_HOSTNAME_} -c1 | sed '1{s/[^(]*(//;s/).*//;q}'`



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

timeout 10 sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no ${username}@${HOSTNAME} ${COMMAND} 2>/dev/null
}

DEFINE_MASTER_SLAVE_SNAPSHOT_NAME () {
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

_HOSTNAME_MASTER_IP_=`ping ${_HOSTNAME_MASTER_} -c1 | sed '1{s/[^(]*(//;s/).*//;q}'`
_HOSTNAME_SLAVE_IP_=`ping ${_HOSTNAME_SLAVE_} -c1 | sed '1{s/[^(]*(//;s/).*//;q}'`
VM_SNAPSHOT_NAME=${_HOSTNAME_VIP_}_upgrade_to_${UPGRADE_HANA_VERSION}
}


STOP_HANA_CLUSTER () {
# HANA stop
echo "************************"
echo "Stopping HANA on ${1}"
echo "************************"
OS_COMMAND ${1} $password "sudo -i -u hybadm HDB stop"

}

STOP_VM_CLUSTER () {
#vm stop
echo "************************"
echo "Stopping OS on ${1}"
echo "************************"
OS_COMMAND ${1} $password "sudo /sbin/init 0"
sleep 60
if  [[ `${COMMAND_GOVC} vm.info ${1} | grep "Power state" | awk '{ printf $3"\n" }'` != poweredOff ]] ;then
        _HOSTNAME_UUID_=`${COMMAND_GOVC} vm.info ${1} | grep UUID | awk '{ printf $2 }'`
        ${COMMAND_GOVC} vm.power -vm.uuid=${_HOSTNAME_UUID_} -off
fi
}

STARTUP_VM_CLUSTER () {
echo "************************"
echo "Starting OS on ${1}"
echo "************************"
# ${COMMAND_GOVC} vm.power -vm.ip=${_HOSTNAME_} -on
_HOSTNAME_MASTER_UUID_=`${COMMAND_GOVC} vm.info ${1} | grep UUID | awk '{ printf $ 2 }'`

#vm start
${COMMAND_GOVC} vm.power -vm.uuid=${_HOSTNAME_MASTER_UUID_} -on

}

RESET_CLUSTER_VM () {
echo "************************"
echo "Restarting OS on ${1}"
echo "************************"
_HOSTNAME_MASTER_UUID_=`${COMMAND_GOVC} vm.info ${_HOSTNAME_MASTER_} | grep UUID | awk '{ printf $ 2 }'`
_HOSTNAME_SLAVE_UUID_=`${COMMAND_GOVC} vm.info ${_HOSTNAME_SLAVE_} | grep UUID | awk '{ printf $ 2 }'`

#${COMMAND_GOVC} vm.power -vm.ip=${_HOSTNAME_IP_} -reset
#master vm restart
${COMMAND_GOVC} vm.power -vm.uuid=${_HOSTNAME_MASTER_UUID_} -reset
#slave vm restart
${COMMAND_GOVC} vm.power -vm.uuid=${_HOSTNAME_SLAVE_UUID_} -reset
}

CREATE_VM_SNAPSHOT () {
echo "*************************"
echo "Create    ${1}   snapshot"
echo "*************************"
#Does not include memory state
${COMMAND_GOVC} snapshot.create -m=false -vm ${1} ${2}
}

CHECK_VM_SNAPSHOT_STATUS () {
echo "*************************"
echo "Check ${1} snapshot status"
echo "*************************"
LOOP_COUNT=0
LOOP_COUNT_THRESHOLD=6

until [ $LOOP_COUNT -ge ${LOOP_COUNT_THRESHOLD} ]
do

if [[ `${COMMAND_GOVC} snapshot.tree -vm ${1} -D -i | grep ${2} | wc -l` -ge 1 ]] ;then
	echo ${1}" snapshot OK"
	LOOP_COUNT=6
else
	sleep 30
	let LOOP_COUNT++
	if [[ $LOOP_COUNT -eq ${LOOP_COUNT_THRESHOLD} ]] ;then
		echo "The snapshot ${1} is not finished."
		exit 0
	fi
fi

done
}


CHECK_VM_STATUS () {
echo "*************************"
echo "Check ${1} VM status"
echo "*************************"
LOOP_COUNT=0
LOOP_COUNT_THRESHOLD=9

until [ $LOOP_COUNT -ge ${LOOP_COUNT_THRESHOLD} ]
do

if [[ `OS_COMMAND ${1} $password "/usr/bin/hostname"` ]] ;then
	echo ${1}" OS connection is normal"
	LOOP_COUNT=9
else
        sleep 30
        let LOOP_COUNT++
        if [[ $LOOP_COUNT -eq ${LOOP_COUNT_THRESHOLD} ]] ;then
           echo "The start ${1} is not finished."
           exit 0
        fi
fi

done

}

CHECK_HANA_CLUSTER_MASTER_STATUS () {
for i in {1..9};do
        HANA_MASTER_STATUS=`OS_COMMAND ${1} $password "sudo /usr/sbin/pcs status| grep 'Masters:' | grep node | wc -l"`
        HANA_MASTER_ERROR_STATUS=`OS_COMMAND ${1} $password "sudo /usr/sbin/pcs status | grep 'Failed Actions:' | wc -l"`
        if [[ ${HANA_MASTER_ERROR_STATUS} -eq 0 ]] ;then
                if [[ ${HANA_MASTER_STATUS} -eq 1 ]] ;then
                        echo "HHANA master started successful."
                        OS_COMMAND ${1} $password "sudo /usr/sbin/pcs node unmaintenance ${_HOSTNAME_SLAVE_ALIAS_NAME_}"
                        break
                else
                        echo "Unmaintenance Master node ..."
                        if [[ $i -eq 9 ]] ;then
							exit 0
                        fi
                        sleep 30
                fi
        else
                echo "Cluster status has error. Please check."
                exit 0
        fi
done
}

CHECK_HANA_CLUSTER_SLAVE_STATUS () {
#HANA_MASTER_ERROR_STATUS=`OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo /usr/sbin/pcs status" | grep "Failed Actions:" |wc -l`
for i in {1..9};do
HANA_MASTER_ERROR_STATUS=`OS_COMMAND ${1} $password "sudo /usr/sbin/pcs status" | grep "Failed Actions:" |wc -l`
	if [[ ${HANA_MASTER_ERROR_STATUS} -eq 0 ]] ;then
		if [[ `OS_COMMAND ${1}$password "sudo /usr/sbin/pcs status| grep 'Slaves:' | grep node | wc -l"` -eq 1 ]] ;then
			echo "HANA slave started successful."
			break
		else
			echo "Unmaintenance Slave node ..."
			if [[ $i -eq 9 ]] ;then
				exit 0
			fi
			sleep 30
		fi
	else
		echo "Cluster status has error. Please check."
	fi
done
}


###############################################################
###################### main process ###########################
###############################################################

#Define master slave snapshot_name
DEFINE_MASTER_SLAVE_SNAPSHOT_NAME ${_HOSTNAME_VIP_}

#Check HANA cluster and database replication status
echo "========================================================="
echo "====== Checking HANA cluster and replication status ====="
echo "========================================================="
REPLICATION_STATUS=`OS_COMMAND $_HOSTNAME_VIP_ $password "sudo -i -u hybadm hsrinfo | grep 'overall' |cut -d':' -f2"`
HANA_MASTER_ERROR_STATUS=`OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo /usr/sbin/pcs status | grep 'Failed Actions:' |wc -l"`
HANA_MASTER_STATUS=`OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo /usr/sbin/pcs status| grep 'Masters:' | grep node | wc -l"`
HANA_SLAVE_STATUS=`OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo /usr/sbin/pcs status| grep 'Slaves:' | grep node | wc -l"`

if [[ ${HANA_MASTER_ERROR_STATUS} -eq 0 ]]; then
        if [[ ${HANA_MASTER_STATUS} -eq 1 ]]; then
                if [[ ${HANA_SLAVE_STATUS} -eq 1 ]];then
                        if [[ ${REPLICATION_STATUS} -eq "ACTIVE" ]]; then
                                echo "HANA cluster and database replication status OK."
                        else
                                echo "HANA database replication error, please check."
                                exit 0
                        fi
                else
                        echo "HANA cluster Slave status error, please check."
                        exit 0
                fi
        else
                echo "HANA cluster Master status error, please check."
                exit 0
        fi
else
        echo "HANA cluster Failed Actions, please check."
        echo `OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo /usr/sbin/pcs status | grep -A 4 'Failed Actions:'"`
        exit 0
fi



###Before upgrade required
echo "==========================================================="
echo "===== Starting pre-upgrade steps to update parameters ====="
echo "==========================================================="
${_WORKSPACE_DIR_PATH_}/before.sh ${_HOSTNAME_VIP_} ${username} ${password}
OS_COMMAND $_HOSTNAME_VIP_ $password "sudo cat /tmp/upgrade_before_configure_alerts_${_HOSTNAME_VIP_}.log"
echo "Pre-upgrade steps Done."
echo ""



###Set maintenance cluster
echo "==============================="
echo "===== Maintenance cluster ====="
echo "==============================="
OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo /usr/sbin/pcs node maintenance --all"
sleep 30

#Stop HANA
STOP_HANA_CLUSTER ${_HOSTNAME_SLAVE_}
STOP_HANA_CLUSTER ${_HOSTNAME_MASTER_}
sleep 30
STOP_HANA_CLUSTER ${_HOSTNAME_SLAVE_}
STOP_HANA_CLUSTER ${_HOSTNAME_MASTER_}

#Stop vm. First start slave，then start master
STOP_VM_CLUSTER ${_HOSTNAME_SLAVE_}
sleep 5
STOP_VM_CLUSTER ${_HOSTNAME_MASTER_}

#Create a shutdown snapshot
for _HOSTNAME_ in ${_HOSTNAME_SLAVE_} ${_HOSTNAME_MASTER_} ;do
	if  [[ `${COMMAND_GOVC} vm.info ${_HOSTNAME_} | grep "Power state" | awk '{ printf $3"\n" }'` == poweredOff ]] ;then
			CREATE_VM_SNAPSHOT ${_HOSTNAME_} ${VM_SNAPSHOT_NAME}
	else
			echo "The ${_HOSTNAME_} is not powered off."
			exit 0
	fi
done

#Check vm snapshot status
CHECK_VM_SNAPSHOT_STATUS ${_HOSTNAME_MASTER_} ${VM_SNAPSHOT_MASTER_NAME}
CHECK_VM_SNAPSHOT_STATUS ${_HOSTNAME_SLAVE_} ${VM_SNAPSHOT_SLAVE_NAME}

#Start VM. First start master，then start slave
STARTUP_VM_CLUSTER ${_HOSTNAME_MASTER_}
sleep 30
STARTUP_VM_CLUSTER ${_HOSTNAME_SLAVE_}

#Check if the OS can connect
CHECK_VM_STATUS ${_HOSTNAME_MASTER_}
CHECK_VM_STATUS ${_HOSTNAME_SLAVE_}



###Upgrade OS kernel
echo "===================================="
echo "====== Starting kernal upgrade ====="
echo "===================================="
for _HOSTNAME_ in ${_HOSTNAME_MASTER_} ${_HOSTNAME_SLAVE_} ;do
        if [[ `OS_COMMAND $_HOSTNAME_ $password "sudo /bin/uname -av | grep "${KERNEL_VERSION}" | wc -l"` -lt 1 ]] ;then
                sshpass -p ${password} /usr/bin/scp ${_WORKSPACE_DIR_PATH_}/${UPGRADE_OS_KERNEL_SCRIPT}  ${username}@${_HOSTNAME_}:/tmp/
                ${_WORKSPACE_DIR_PATH_}/rrun_command.exp ${password} ${_HOSTNAME_} ${UPGRADE_OS_KERNEL_SCRIPT}
        fi
done

sleep 30

#Restart VM and check OS kernel upgrade done
echo "=========================="
echo "====== Restarting VM ====="
echo "=========================="
for _HOSTNAME_ in ${_HOSTNAME_MASTER_} ${_HOSTNAME_SLAVE_} ;do
        echo "Restarting ${_HOSTNAME_} ..."
        OS_COMMAND ${_HOSTNAME_} $password "sudo /sbin/init 6"
        sleep 30
done

#Check if the OS can connect
CHECK_VM_STATUS ${_HOSTNAME_MASTER_}
CHECK_VM_STATUS ${_HOSTNAME_SLAVE_}

#Check OS upgrade status
for _HOSTNAME_ in ${_HOSTNAME_MASTER_} ${_HOSTNAME_SLAVE_} ;do
        if [[ `OS_COMMAND $_HOSTNAME_ $password "sudo /bin/uname -av | grep "${KERNEL_VERSION}" | wc -l"` -eq 1 ]];then
                echo "${_HOSTNAME_} kernel upgrade has succeed."
        else
                echo "${_HOSTNAME_} kernel upgrade has failed. Please revert VM snapshot and try again."
                exit 0
        fi
done

#set master unmaintenance
echo "=================================="
echo "====== Unmaintenance Cluster ====="
echo "=================================="
echo "Master node is  "${_HOSTNAME_MASTER_}

OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo /usr/sbin/pcs node unmaintenance ${_HOSTNAME_MASTER_ALIAS_NAME_}"
sleep 60

#Check cluster Master status and set slave unmaintenance
CHECK_HANA_CLUSTER_MASTER_STATUS ${_HOSTNAME_MASTER_}

#Check cluster Slaves status
CHECK_HANA_CLUSTER_SLAVE_STATUS ${_HOSTNAME_MASTER_}



###Upgrade HANA version
echo "==============================="
echo "====== Start HANA upgrade ====="
echo "==============================="
AFTER_UPGRADE_HANA_VERSION=`OS_COMMAND $_HOSTNAME_VIP_ $password "sudo -i -u hybadm HDB version | grep "version:" | cut -d"." -f4"`
if  [[ `${COMMAND_GOVC} vm.info ${_HOSTNAME_SLAVE_} | grep "Power state" | awk '{ printf $3"\n" }'` == poweredOn ]] ;then
        if [[ ${AFTER_UPGRADE_HANA_VERSION} -ne ${UPGRADE_HANA_VERSION} ]]; then
                sshpass -p ${password} /usr/bin/scp ${_WORKSPACE_DIR_PATH_}/${UPGRADE_HANA_SCRIPT}  ${username}@${_HOSTNAME_SLAVE_}:/tmp/
                ${_WORKSPACE_DIR_PATH_}/rrun_command.exp.hybadm ${password} ${_HOSTNAME_SLAVE_} ${UPGRADE_HANA_SCRIPT} ${HANA_OWNER}
        else
                echo "HANA version has been ${AFTER_UPGRADE_HANA_VERSION}, no need to upgrade."
        fi
fi

sleep 30

#Check HANA upgrade status
echo "====================================="
echo "===== Check HANA upgrade status ====="
echo "====================================="
#AFTER_UPGRADE_HANA_VERSION=`OS_COMMAND $_HOSTNAME_MASTER_ $password "sudo -i -u hybadm HDB version | grep '1.00' |awk -F'.' '{print $4}'"`
AFTER_UPGRADE_HANA_VERSION=`OS_COMMAND $_HOSTNAME_VIP_ $password "sudo -i -u hybadm HDB version | grep 'version:' | cut -d'.' -f4"`
REPLICATION_STATUS=`OS_COMMAND $_HOSTNAME_VIP_ $password "sudo -i -u hybadm hsrinfo | grep 'overall' |cut -d":" -f2"`
if [[ "${AFTER_UPGRADE_HANA_VERSION}" -eq "${UPGRADE_HANA_VERSION}" ]] ;then
        if [[ ${REPLICATION_STATUS} -eq "ACTIVE" ]] ;then
                echo "HANA replication status good."
        else
                echo "HANA replication has errors. Please check."
        fi

        echo "HANA upgrade completed successfully."
else
        echo "HANA upgrade failed."
fi



###After upgrade required
echo "=============================="
echo "===== Post upgrade steps ====="
echo "=============================="
${_WORKSPACE_DIR_PATH_}/after.sh ${_HOSTNAME_VIP_} ${username} ${password}
OS_COMMAND $_HOSTNAME_VIP_ $password "sudo cat /tmp/upgrade_after_configure_alerts_${_HOSTNAME_VIP_}.log"


###Security Remediation
for _HOSTNAME_ in ${_HOSTNAME_MASTER_} ${_HOSTNAME_SLAVE_};do
        OS_COMMAND $_HOSTNAME_ $password "sudo /usr/bin/rm -rf /opt/vmware-jre/lib/rt.jar"
        OS_COMMAND $_HOSTNAME_ $password "sudo /bin/chmod 750 ~nagios"
        OS_COMMAND $_HOSTNAME_ $password "sudo /bin/chmod 750 ~nfsnobody"
        OS_COMMAND $_HOSTNAME_ $password "sudo /bin/chmod 2750 ~uuidd"
        OS_COMMAND $_HOSTNAME_ $password "sudo /usr/bin/rm -f /tmp/*.sql"
        OS_COMMAND $_HOSTNAME_ $password "sudo /usr/bin/rm -f /tmp/upgrade_*_${_HOSTNAME_VIP_}.log"
done

echo "Post upgrade steps Done."