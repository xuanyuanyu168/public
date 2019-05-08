一、主要技术点
1、VMware 虚拟机操作（重启VM、创建快照、删除快照、恢复快照等）
2、OS层，升级OS kernel
3、数据库层，升级HANA数据库、调整数据库参数。

二、使用范围
This script is for CC1.0 patch and HANA upgrade.
This script is based on the DBA wiki URL:https://wiki.hybris.com/pages/viewpage.action?pageId=446249119 development

HANA version:	122.17
OS version: RHEL7.4
Linux Kernel version: 3.10.0-693.43.1.el7.x86_64
Kernel Release Date: Oct 11 2018
Certified On: Feb 8 2019
Release to Operations Team: Feb 11 2019
					
Introduction to running script methods(This article takes CC1.0 MA as an example).
==========================================================================================
Kernel patch and HANA upgrade:

Step 1: Environment variable configuration(Example：MA env)
Login to the jumpserver home directory:
hongbin_wang@inf-p-ma-ljp-001:~$ vim .profile 
Add at the end of the file:
source ~/.govc/govc_profile
username@inf-p-ma-ljp-001:~$ mkdir .gove 
username@inf-p-ma-ljp-001:~$ vim .govc/govc_profile 
export GOVC_INSECURE=1
export GOVC_URL='https://10.16.2.94/sdk'          (FR:GOVC_URL='https://10.32.2.16/sdk')
export GOVC_USERNAME='hybrishosting\username' (username)
export GOVC_PASSWORD='sQYMAelQjOjbE12p'           (password)
export GOVC_DATACENTER='MA-Boston'                (FR:GOVC_DATACENTER='FR-Frankfurt')
export GOVC_GUEST_LOGIN='root:*'
username@inf-p-ma-ljp-001:~$ 

Step 2: Upload script to home directory(HANA_cluster_upgrade)
username@inf-p-ma-ljp-001:~$ ls
HANA_cluster_upgrade
username@inf-p-ma-ljp-001:~$ cd HANA_cluster_upgrade
username@inf-p-ma-ljp-001:~/HANA_cluster_upgrade$ chmod +x *.sh rrun_command.exp*
username@inf-p-ma-ljp-001:~/HANA_cluster_upgrade$ ls -al
total 80
drwxr-xr-x  2 username linux-sysadmin  4096 Apr  2 10:13 .
drwx------ 15 username linux-dba       4096 Apr  2 10:10 ..
-rw-r--r--  1 username linux-sysadmin  1731 Apr  2 10:10 10.sql
-rw-r--r--  1 username linux-sysadmin  1742 Apr  2 10:10 20.sql
-rw-r--r--  1 username linux-sysadmin  1734 Apr  2 10:10 60.sql
-rw-r--r--  1 username linux-sysadmin  1731 Apr  2 10:10 6.sql
-rwxr-xr-x  1 username linux-sysadmin   463 Apr  2 10:13 after.sh
-rwxr-xr-x  1 username linux-sysadmin   675 Apr  2 10:13 before.sh
-rwxr-xr-x  1 username linux-sysadmin 14656 Apr  2 10:10 main.sh
-rw-r--r--  1 username linux-sysadmin   556 Apr  2 10:10 post_upgrade.sql
-rw-r--r--  1 username linux-sysadmin  2357 Apr  2 10:10 README.txt
-rwxr-xr-x  1 username linux-sysadmin  4002 Apr  2 10:10 remove_vm_snapshot.sh
-rwxr-xr-x  1 username linux-sysadmin  3413 Apr  2 10:10 revert_vm_snapshot.sh
-rwxr-xr-x  1 username linux-sysadmin   904 Apr  2 10:10 rrun_command.exp
-rwxr-xr-x  1 username linux-sysadmin   846 Apr  2 10:10 rrun_command.exp.hybadm
-rwxr-xr-x  1 username linux-sysadmin   166 Apr  2 10:10 upgrade_HANA.sh
-rwxr-xr-x  1 username linux-sysadmin   909 Apr  2 10:10 upgrade_os_kernel.sh
username@inf-p-ma-ljp-001:~/HANA_cluster_upgrade$ 
**Annotation：
main.sh： main script
remove_vm_snapshot.sh： Delete snapshot script
revert_vm_snapshot.sh： Recovery snapshot script

Step 3: Cluster Kernel patch and HANA upgrade
username@inf-p-ma-ljp-001:~/HANA_cluster_upgrade$ ./main.sh h21-p-ma-hdb-vip
For Example: ./main.sh tmc-p-ma-hdb-vip
Please input your password: you_password
*Wait for the script to run, check the results*


==========================================================================================
Delete snapshot：

username@inf-p-ma-ljp-001:~/HANA_cluster_upgrade$ ./remove_vm_snapshot.sh h21-p-ma-hdb-vip
For Example: ./remove_vm_snapshot.sh tmc-p-ma-hdb-vip
Please input your password: you_password
*Wait for the script to run, check the results*


==========================================================================================
Recovery snapshot：

username@inf-p-ma-ljp-001:~/HANA_cluster_upgrade$ ./revert_vm_snapshot.sh h21-p-ma-hdb-vip
For Example: ./revert_vm_snapshot.sh tmc-p-ma-hdb-vip
Please input your password: you_password
*Wait for the script to run, check the results*


