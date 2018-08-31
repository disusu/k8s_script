#!/bin/bash
#
# Filename: install_master.sh
# Date: Mon Aug 15 CST 2018
# Author: SuDi
# Email: i-disu@pptv.com
# Description: Interactive or Automatic Install K8s Master
# Config: /app/script/resource/{config,kube-scheduler,kube-apiserver,kube-controller-manager}
# Service Config: /app/script/resource/{kube-apiserver.service,kube-scheduler.service,kube-scheduler.service}
if [ "$1" == "--help" ]; then
  printf -- 'Usage: sh install_master.sh \n';
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

function INSTALL_EXEC() {
   if [[ $INSTALL == YES ]];then
    wget -c -P ${MASTER_INSTALL_PATH} http://mirrors.dilinux.cn/src/1.11.2/kubernetes-server-linux-amd64.tar.gz &>/dev/null
    tar -xf ${MASTER_INSTALL_PATH}/kubernetes-server-linux-amd64.tar.gz -C ${MASTER_INSTALL_PATH}
    cp ${MASTER_INSTALL_PATH}/kubernetes/server/bin/{kube-scheduler,kube-controller-manager,kube-apiserver} /usr/local/bin/
    CHECK_STATUS "Install Server Exec File"
   else
    LOG_PRINT INFO "You Already Installed kube-scheduler,kube-controller-manager,kube-apiserver"
    sleep 5
   fi
}

function INIT_FILE() {
#kube-apiserver
   cat  ${RESOURCE_PATH}/config >${CONFIG_FILE_PATH}/config
   LOG_PRINT OK "Create Config Is ${CONFIG_FILE_PATH}/config"
   sed "s@192.168.117.132@${MASTER_IP}@g;s@ETCD_IPS@${ETCD_ENDPOINTS}@g;s@SVC_CIRD@${SERVICE_CIDR}@g" ${RESOURCE_PATH}/kube-apiserver >${CONFIG_FILE_PATH}/kube-apiserver
   LOG_PRINT OK "Kube-apiserver Config Is ${CONFIG_FILE_PATH}/kube-apiserver"
   sed "s@SECRET_KEY@${ENCRYPTION_KEY}@g" ${RESOURCE_PATH}/encryption-config.yaml >${CONFIG_FILE_PATH}/encryption-config.yaml
   cat ${RESOURCE_PATH}/kube-apiserver.service > /usr/lib/systemd/system/kube-apiserver.service
   systemctl enable kube-apiserver.service &>/dev/null
   LOG_PRINT OK "Enable Kube-apiserver"
#kube-controller-manager
   sed "s@SVC_CIRD@${SERVICE_CIDR}@g;s@POD_CIRD@${CLUSTER_CIDR}@g" ${RESOURCE_PATH}/kube-controller-manager.service >/usr/lib/systemd/system/kube-controller-manager.service 
   systemctl daemon-reload
   systemctl enable kube-controller-manager.service >/dev/null
   LOG_PRINT OK "Enable kube-controller-manager"
#kube-scheduler
   cat ${RESOURCE_PATH}/kube-scheduler > ${CONFIG_FILE_PATH}/kube-scheduler
   LOG_PRINT OK "Kube-scheduler Config Is ${CONFIG_FILE_PATH}/kube-scheduler"
   cat ${RESOURCE_PATH}/kube-scheduler.service > /usr/lib/systemd/system/kube-scheduler.service
   systemctl daemon-reload
   systemctl enable kube-scheduler.service >/dev/null
   LOG_PRINT OK "Enable kube-scheduler"
#etcdctl create key
  etcdctl --endpoints=${ETCD_ENDPOINTS} --ca-file=${CONFIG_FILE_PATH}/ca.pem  --cert-file=${CONFIG_FILE_PATH}/kubernetes.pem --key-file=${CONFIG_FILE_PATH}/kubernetes-key.pem mkdir /kube/network
  LOG_PRINT OK "Mkdir Etcd Key /kube/network"
  etcdctl --endpoints=${ETCD_ENDPOINTS} --ca-file=${CONFIG_FILE_PATH}/ca.pem  --cert-file=${CONFIG_FILE_PATH}/kubernetes.pem --key-file=${CONFIG_FILE_PATH}/kubernetes-key.pem mk /kube/network/config "{\"Network\":\"${CLUSTER_CIDR}\",\"SubnetLen\":24,\"Backend\":{ \"Type\": \"vxlan\", \"VNI\": 1}}"
  LOG_PRINT OK "Create Flanneld Config"
}

function main() {
  stty erase ^H
  source $(pwd)/env.sh
  COUNT=0
  while (($COUNT < 1)) ;do
    read -p "This Node is Master? [Y/N]: " PARA_ONE
    if [[ $PARA_ONE == Y || $PARA_ONE == y ]];then
      LOG_PRINT OK "Master Ip is $MASTER_IP"
    else
      LOG_PRINT ERROR "Please Exec This Script On Your Master Node!!!"
    fi
    read -p "Are You sure That You Input is true? [Y/N]: " PARA
    if [[ $PARA == Y || $PARA == y ]];then
       COUNT=2
    else
       COUNT=0
    fi
  done
  RESOURCE_PATH=$(pwd)/resource
  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
  INSTALL_EXEC
  INIT_FILE
  LOG_PRINT OK "Now You Can Exec Script: systemctl start kube-apiserver && systemctl start kube-controller-manager && systemctl start kube-scheduler"
}

main
