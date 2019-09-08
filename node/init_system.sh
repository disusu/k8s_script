#!/bin/bash
#
# Filename: init_systemd.sh
# Date: Mon Aug 23 CST 2018
# Author: SuDi
# Email: disusre@gmail.com
# Description: Interactive or Automatic Init Systemd

if [ "$1" == "--help" ]; then
  printf -- 'Usage: sh init_systemd.sh \n';
  exit 0;
fi

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin


function LOG_PRINT() {
    local LEVEL=$1
    local TEXT=$2
    case $LEVEL in
        OK)
            #绿色
            echo -e "\033[32m $TEXT \033[0m"
        ;;
        INFO)
            #蓝色
            echo -e "\033[34m $TEXT \033[0m"
        ;;
        WARNING)
            #黄色
            echo -e "\033[33m $TEXT \033[0m"
        ;;
        ERROR)
            #红色
            echo -e "\033[31m $TEXT \033[0m"
            exit 2
        ;;
        *)
            echo "INVALID OPTION (LOG_PRINT): $1"
            exit 1
        ;;
    esac
}

function CHECK_STATUS() {
    if [ $? -eq 0 ];then
        LOG_PRINT OK "$1 成功"
    else
        LOG_PRINT WARNING "$1 失败！！！"
        exit 2
    fi
}

function INIT_SYSTEMD() {
#DISABLE SELINUX
   setenforce 0 && sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config
   CHECK_STATUS "DISABLE SELINUX"
#INIT IPTABLES
   systemctl stop firewalld.service; yum -y install iptables-services; systemctl mask firewalld.service
   cat ${RESOURCE}/iptables >/etc/sysconfig/iptables
   systemctl restart iptables
   CHECK_STATUS "INIT IPTABLES"
#INSTALL DEPENDENT PACKAGE
   yum install -y wget epel-release conntrack ipvsadm ipset jq sysstat curl libseccomp &>/dev/null
   CHECK_STATUS "INSTALL DEPENDENT PACKAGE"
#CLOSE SWAP
   swapoff -a
   CHECK_STATUS "CLOSE SWAP"
#LOADING KERNEL MODULES
   IPVS_MODULES="br_netfilter ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4"
   for IPVS_MODULE in ${IPVS_MODULES}; do
     modinfo -F filename ${IPVS_MODULE} > /dev/null 2>&1
     if [ $? -eq 0 ]; then
        modprobe ${IPVS_MODULE}
     fi 
   done 
   CHECK_STATUS "LOADING KERNEL MODULES"
#SET SYSTEMD PARAMETER
   cat ${RESOURCE}/kubernetes.conf >/etc/sysctl.d/kubernetes.conf
   sysctl -p /etc/sysctl.d/kubernetes.conf
   CHECK_STATUS "SET SYSTEMD PARAMETER"
}

function main() {
  RESOURCE=$(pwd)/resource
  INIT_SYSTEMD
  LOG_PRINT OK "System Will Reboot After 10s,If You Need Save Something,You Can Press Ctrl+C Close It!"
  sleep 10
  sync && sync && shutdown -r now
}
main
