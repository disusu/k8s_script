#!/bin/bash
#
# Filename: install_flannel.sh
# Date: Mon Aug 15 CST 2018
# Author: SuDi
# Email: i-disu@pptv.com
# Description: Interactive or Automatic Install K8s Network Flannel
# Config: /app/script/resource/flanneld.service

if [ "$1" == "--help" ]; then
  printf -- 'Usage: sh install_flannel.sh \n';
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

function INIT_NETWORK() {
#install flanneld
  if [[ $INSTALL == YES ]];then
   wget -c -P ${FLANNELD_INSTALL_PATH} http://mirrors.dilinux.cn/src/flannel-v0.10.0-linux-amd64.tar.gz &>/dev/null
   tar -xf ${FLANNELD_INSTALL_PATH}/flannel-v0.10.0-linux-amd64.tar.gz -C ${FLANNELD_INSTALL_PATH} && cp ${FLANNELD_INSTALL_PATH}/{flanneld,mk-docker-opts.sh} /usr/local/bin/
   LOG_PRINT OK "Flannel Install"
  else
   LOG_PRINT INFO "You Already Installed Flannel"
   sleep 5
  fi
  sed "s@ETCD_IPS@${ETCD_ENDPOINTS}@g" ${RESOURCE_PATH}/flanneld.service > /usr/lib/systemd/system/flanneld.service
  systemctl daemon-reload
  systemctl enable flanneld.service &>/dev/null
  LOG_PRINT OK "Enable flanneld"
}

function INSTALL_DOCKER() {
#install docker
  if [[ $PARA_ONE == Y || $PARA_ONE == y ]];then
     LOG_PRINT INFO "Install Docker Beginning"
     yum install -y yum-utils device-mapper-persistent-data lvm2 &>/dev/null
     yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo &>/dev/null
     yum install docker-ce -y &>/dev/null
     LOG_PRINT OK "Install Docker Finish"
#init docker file
     sed "s@HUB_ADDR@${DOCKER_REGISTRY}@g" ${RESOURCE_PATH}/docker.service >/usr/lib/systemd/system/docker.service
     systemctl daemon-reload
     systemctl enable docker.service &>/dev/null
  else
     sed "s@HUB_ADDR@${DOCKER_REGISTRY}@g" ${RESOURCE_PATH}/docker.service >/usr/lib/systemd/system/docker.service
     systemctl daemon-reload
     systemctl enable docker.service &>/dev/null
  fi
}

function main() {
  stty erase ^H
  source $(pwd)/env.sh
  COUNT=0
  while (($COUNT < 1)) ;do
    read -p "Install Docker? [Y/N]: " PARA_ONE
    read -p "Are You sure That You Input is true? [Y/N]: " PARA
    if [[ $PARA == Y || $PARA == y ]];then
       COUNT=2
    else
       COUNT=0
    fi
  done
  RESOURCE_PATH=$(pwd)/resource
  mkdir ${FLANNELD_INSTALL_PATH} -p
  INIT_NETWORK
  INSTALL_DOCKER
  LOG_PRINT INFO "Now You Can Exec Script: systemctl restart flanneld && systemctl restart docker"
}
main
