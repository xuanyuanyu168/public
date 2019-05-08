#!/bin/bash

UPGRADE_OS_VERSION=3.10.0-693
#UPGRADE_OS_VERSION=7.6

UPGRADE_OS_KERNEL () {

mount -t nfs4 nfs-db:/repo/HanaDB /mnt/hana

yum localinstall -y /mnt/hana/kernel/dracut-033-502.el7_4.2.x86_64.rpm        

yum localinstall -y /mnt/hana/kernel/linux-firmware-20170606-58.2.gitc990aae.el7_4.noarch.rpm        

yum localinstall -y /mnt/hana/kernel/kernel-3.10.0-693.43.1.el7.x86_64.rpm

### as follow upgrade cc1.2
#puppet agent --disable
#subscription-manager release --set=${UPGRADE_OS_VERSION}
#yum clean all
#rm -fr /var/cache/yum/*

#if [[ `subscription-manager release --show` == *${UPGRADE_OS_VERSION}* ]] ;then
#yum -y upgrade --disableexcludes=all
#fi

}

#if [[ `cat /etc/redhat-release | grep ${UPGRADE_OS_VERSION} | wc -l` -lt 1 ]] ;then
#  UPGRADE_OS_KERNEL
#else
#  puppet agent --enable
#fi

if [[ `uname -av | grep '${UPGRADE_OS_VERSION}' | wc -l` -lt 1 ]] ;then
UPGRADE_OS_KERNEL
fi
