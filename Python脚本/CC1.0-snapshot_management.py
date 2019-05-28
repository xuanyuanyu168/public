#!/usr/bin/python
# -*- coding=utf-8 -*-

"""
Instructions for use:
create snapshot：
snapshot_management.py -c -vm tmc-p-ma-app-002 -n tmc-p-ma-app-002-20190528
revert snapshot：
snapshot_management.py -r -vm tmc-p-ma-app-002 -n tmc-p-ma-app-002-20190528
delete snapshot：
snapshot_management.py -d -vm tmc-p-ma-app-002 -n tmc-p-ma-app-002-20190528
list snapshot：
snapshot_management.py -vm tmc-p-ma-app-002 -l
"""
import argparse
import getpass
import json
import os
import socket
import subprocess
import time
import paramiko as paramiko
import commands


def _argparse():
    parser = argparse.ArgumentParser(
        description=""" snapshot_management.py -c -vm tmc-p-ma-app-002 -n tmc-p-ma-app-002-20190528""")

    parser.add_argument('-vm', '--host', action='store', dest='hostname', required=True, help='Connect to virtual machine (tmc-p-ma-app-001)')
    parser.add_argument('-c', '--create_snapshot', action='store_true', dest='create_snapshot',required=False, help='Create snapshot of VM with NAME.')
    parser.add_argument('-r', '--revert_snapshot', action='store_true', dest='revert_snapshot',required=False, help='Revert to snapshot of VM with given NAME.')
    parser.add_argument('-d', '--delete_snapshot', action='store_true', dest='delete_snapshot',required=False,help='Delete snapshot of VM with given NAME.')
    parser.add_argument('-l', '--list_snapshot', action='store_true', dest='list_snapshot', required=False, help='List VM snapshots in a tree-like format.')
    parser.add_argument('-n', '--snapshot_name', action='store', dest='snapshot_name', help='Virtual machine snapshot name')
    args = parser.parse_args()
    # if not args.password:
    #     args.password = getpass.getpass(
    #         prompt='Enter password')
    #
    return args

def create_snapshot(hostname,snapshot_name):
    # ${COMMAND_GOVC}  snapshot.create - vm ${1} ${2}
    commands.getoutput("govc snapshot.create -m=false -vm %s %s" % (hostname, snapshot_name))


def check_snapshot_status(hostname,snapshot_name):
    snapshot_status= False
    faild_count=0
    while faild_count <= 3:
        res = commands.getoutput("govc snapshot.tree -vm %s -D -i | grep -c %s" %(hostname,snapshot_name))
        if res >= 1:
            snapshot_status=True
            break
        else:
            time.sleep(30)
            faild_count +=1
    return snapshot_status

def revert_snapshot(hostname,snapshot_name):
    if check_snapshot_status(hostname,snapshot_name):
        res=commands.getstatusoutput("govc snapshot.revert -vm %s %s" %(hostname,snapshot_name))
        time.sleep(30)
        if res[0] == 0:
            return True
        else:
            print(res[1])
    else:
        print("The %s of the %s does not exist." %(snapshot_name,hostname))


def get_snapshot_name(hostname):
    res = commands.getstatusoutput("govc snapshot.tree -vm %s -D -i" %hostname)
    print(res[1])

def delete_snapshot(hostname,snapshot_name):
    res = commands.getstatusoutput("govc snapshot.tree -vm %s -D -i | grep -c %s" % (hostname, snapshot_name))
    if res[0] == 0:
        res = commands.getstatusoutput("govc snapshot.remove  -vm %s %s" %(hostname,snapshot_name))
        time.sleep(30)
        if res[0] == 0:
            return True
        else:
            print(res[1])
    else:
        print("The %s of the %s does not exist." % (snapshot_name, hostname))
        return


def check_delete_snapshot_status(hostname,snapshot_name):
    snapshot_status= False
    faild_count=0
    while faild_count < 3:
        res = commands.getstatusoutput("govc snapshot.tree -vm %s -D -i | grep -c %s" % (hostname, snapshot_name))
        if res[1] == "0":
            snapshot_status=True
            faild_count = 3
        else:
            time.sleep(30)
            faild_count +=1
    return snapshot_status


def os_command(hostname, cmd):
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname=hostname, port=22, username=username, password=password)
        stdin, stdout, stderr = ssh.exec_command(cmd)
        result = stdout.read()
        #print(result)
        ssh.close()
        return result
    except Exception,e:
        print e


def stop_vm(hostname,vm_uuid):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=hostname, port=22, username=username, password=password)
    stdin, stdout, stderr = ssh.exec_command("sudo /sbin/init 0")

    for i in range(9):
        vm_status = os.popen("govc vm.info -json %s | jq -r .VirtualMachines[].Runtime.PowerState" % hostname).read().replace("\n","")
        if vm_status == "poweredOff":
            print(hostname + " is stop")
            break
        else:
            time.sleep(30)

    subprocess.getoutput("govc vm.power -vm.uuid=%s -off" % vm_uuid)


def start_vm(hostname,vm_uuid):
    start_status = os.popen("/usr/local/bin/govc vm.power -vm.uuid=%s -on" % vm_uuid).read()
    print(start_status)
    for i in range(9):
        res=os_command(hostname,"hostname")
        if not res:
            time.sleep(30)
            print("Try the %s connection" %i)
        else:
            print("%s OS start succeed" %hostname)
            return

def check_server_port(hostname, port):
    sk = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sk.settimeout(5)
    try:
        sk.connect((hostname, port))
        print("%s port %s OK!" %(hostname, port))
    except Exception:
        print("%s port %s not connect!" %(hostname, port))
    sk.close()


def check_server_service(hostname, service):
    service_status = os_command(hostname, "ps -ef | grep -c %s" % service)
    if service_status >= "2":
        print("%s %s is active" %(hostname, service))
    else:
        print("%s %s is failed" %(hostname, service))


def check_server(hostname, server_name):
    web_port = [80, 81, 443, 444]
    app_port = [9001, 9002]
    adm_port = [9001, 9002]
    srch_port = [8983]
    dth_port = [9003, 9004]
    smtp_port = [25]
    sftp_port = [22]
    server_list = {"web": "httpd", "app": "hybris", "adm": "hybris", "srch": "solr", "dth": "tomcat", "smtp": "postfix",
                   "sftp": "sshd"}

    if server_name == "web":
        for port in web_port:
            check_server_port(hostname, port)
        check_server_service(hostname, server_list[server_name])
    elif server_name == "app":
        for port in app_port:
            check_server_port(hostname, port)
        check_server_service(hostname, server_list[server_name])
    elif server_name == "adm":
        for port in adm_port:
            check_server_port(hostname, port)
        check_server_service(hostname, server_list[server_name])
    elif server_name == "srch":
        for port in srch_port:
            check_server_port(hostname, port)
        check_server_service(hostname, server_list[server_name])
    elif server_name == "dth":
        for port in dth_port:
            check_server_port(hostname, port)
        check_server_service(hostname, server_list[server_name])
    elif server_name == "smtp":
        for port in smtp_port:
            check_server_port(hostname, port)
        check_server_service(hostname, server_list[server_name])
    elif server_name == "sftp":
        for port in sftp_port:
            check_server_port(hostname, port)
        check_server_service(hostname, server_list[server_name])
    else:
        print("This service does not support checking")


def main():
    # Parameter instantiation
    parser = _argparse()
    hostname = parser.hostname
    create_snapshot_arg = parser.create_snapshot
    revert_snapshot_arg = parser.revert_snapshot
    delete_snapshot_arg = parser.delete_snapshot
    list_snapshot_arg = parser.list_snapshot
    snapshot_name_arg = parser.snapshot_name

    global username, password
    username = getpass.getuser()
    # password = getpass.getpass("Please input your password:")
    password='!QAZ@WSX3edc'

    # vm info
    vm_res = os.popen("govc vm.info -json %s" % hostname)
    json_data = json.loads(vm_res.read())
    vm_info = json_data["VirtualMachines"]
    vm_status = vm_info[0]["Runtime"]["PowerState"]
    vm_uuid = vm_info[0]["Config"]["Uuid"]

    # Define IDC and server names
    idc_info = hostname.split("-")[2]
    if idc_info == "ma":
        os.putenv('GOVC_URL', 'https://10.16.2.94/sdk')
        os.putenv('GOVC_DATACENTER', 'MA-Boston')
    elif idc_info == "fr":
        os.putenv('GOVC_URL', 'https://10.32.2.16/sdk')
        os.putenv('GOVC_DATACENTER', 'FR-Frankfurt')
    else:
        print("DC does not exist. The supported DC region are as follows")

    server_name = hostname.split("-")[3]

    if list_snapshot_arg:
        get_snapshot_name(hostname)

    if create_snapshot_arg:
        create_snapshot(hostname, snapshot_name_arg)
        snapshot_status = check_snapshot_status(hostname, snapshot_name_arg)
        if snapshot_status:
            print("%s snapshot creation complete" %(hostname))
        else:
            print("%s snapshot creation failed" %(hostname))

    if revert_snapshot_arg:
        revert_snapshot(hostname, snapshot_name_arg)
        vm_status = os.popen("govc vm.info %s | grep 'Power state'" %(hostname)).read().split(' ')[-1].rstrip("\n")
        if vm_status == "poweredOff":
            start_vm(hostname,vm_uuid)
            check_server(hostname, server_name)

    if delete_snapshot_arg:
        delete_snapshot(hostname, snapshot_name_arg)
        snapshot_status = check_delete_snapshot_status(hostname, snapshot_name_arg)
        if snapshot_status:
            print("%s snapshot delete complete" % (hostname))
        else:
            print("%s snapshot delete failed" % (hostname))


# start this thing
if __name__ == "__main__":
    main()
