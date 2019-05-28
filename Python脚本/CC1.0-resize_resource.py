#!/usr/bin/python
# -*- coding=utf-8 -*-

"""
Instructions for use:
1. -l Check current CPU and memory size
python3 resize_cpu_and_memory.py -vm tmc-p-ma-app-002 -l cpu
2、How much CPU and memory are added?
python3 resize_cpu_and_memory.py -vm tmc-p-ma-app-002 -t cpu -s 64
python3 resize_cpu_and_memory.py -vm tmc-p-ma-app-002 -t mem -s 16
"""
import argparse
import getpass
import json
import os
import socket
import subprocess
import time
import paramiko as paramiko


def _argparse():
    parser = argparse.ArgumentParser(
        description=""" Example:python resize_resource.py -vm tmc-p-ma-app-001 -t mem -s 14""")

    parser.add_argument('-vm', '--host', action='store', dest='hostname', required=False,help='Connect to host (tmc-p-ma-app-001)')
    parser.add_argument('-t', '--type', action='store', dest='type', help='Add resource type (cpu|mem)')
    parser.add_argument('-s', '--size', type=int, action='store', dest='size', required=False,help='Add resource size, ram in mb(8192), cpu in core(2))')
    parser.add_argument('-l', '--list', action='store_true', dest='list', required=False,
                        help='List server information')
    args = parser.parse_args()
    # if not args.password:
    #     args.password = getpass.getpass(
    #         prompt='Enter password')
    #
    return args


def add_cpu(hostname, CpuNum):
    os.system("govc vm.change -c %s -vm %s" %(CpuNum, hostname))
    res = os.popen("govc vm.info -json %s | jq -r .VirtualMachines[].Config.Hardware.NumCPU" % hostname)
    print("now CPU :" + res.read())
    print("CPU addition done")


def add_memory(hostname, MemNum):
    os.system("govc vm.change -m %s -vm %s" %(MemNum * 1024, hostname))
    res = os.popen("govc vm.info -json %s | jq -r .VirtualMachines[].Config.Hardware.MemoryMB" %hostname).read().replace("\n","")
    print("now mem size: %s G" %(int(res) / 1024))
    print("Memory addition completed")


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

    os.popen("govc vm.power -vm.uuid=%s -off" % vm_uuid)



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

def ckeck_add_resource(hostname, resource_type):
    resource_size = os.popen("govc vm.info -json %s | jq -r .VirtualMachines[].Config.Hardware.%s" %(hostname, resource_type)).read()
    print hostname, "add", resource_type, resource_size


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


# def create_snapshot():

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
    type = parser.type
    size = parser.size
    list = parser.list

    global username, password
    username = getpass.getuser()
    password = getpass.getpass("Please input your password:")

    # vm info
    vm_res = os.popen("govc vm.info -json %s" % hostname)
    json_data = json.loads(vm_res.read())
    vm_info = json_data["VirtualMachines"]
    memory_hot = vm_info[0]["Config"]["MemoryHotAddEnabled"]
    cpu_hot = vm_info[0]["Config"]["MemoryHotAddEnabled"]
    memory_size = vm_info[0]["Config"]["Hardware"]["MemoryMB"] / 1024
    cpu_size = vm_info[0]["Config"]["Hardware"]["NumCPU"]
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

    if list:
        print("Current CPU size: %s" %(cpu_size))
        print("Current memory size: %s G" %(memory_size))
    if type:
        if type == "cpu":
            if cpu_hot == "true" or vm_status == "poweredOff":
                add_cpu(hostname, size)
            else:
                restart_reconfirm = raw_input("Please confirm your restart:[Y/N]").upper()
                if restart_reconfirm == "Y":
                    stop_vm(hostname,vm_uuid)
                    add_cpu(hostname, size)
                    start_vm(hostname,vm_uuid)
                    ckeck_add_resource(hostname, "NumCPU")
                    check_server(hostname, server_name)
                else:
                    print("CPU not added")
                    return

        elif type == "mem":
            if memory_hot == "true" or vm_status == "poweredOff":
                add_memory(hostname, size)
            else:
                restart_reconfirm = raw_input("Please confirm your restart:[Y/N]").upper()
                if restart_reconfirm == "Y":
                    stop_vm(hostname,vm_uuid)
                    add_memory(hostname, size)
                    start_vm(hostname,vm_uuid)
                    ckeck_add_resource(hostname, "MemoryMB")
                    check_server(hostname, server_name)
                else:
                    print("Memory not added")
                    return
        else:
            print("The resources you added are not supported at this time.")


# start this thing
if __name__ == "__main__":
    main()
