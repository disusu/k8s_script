#!/bin/bash
#
# Filename: install_node.sh
# Date: Mon Aug 15 CST 2018
# Author: SuDi
# Email: i-disu@pptv.com
# Description: Interactive or Automatic Install K8s Node
# Config: /app/script/resource/{config,kubelet,proxy}
# Config Service: /app/script/resource/{kubelet.service,kube-proxy.service}

if [ "$1" == "--help" ]; then
  printf -- 'Usage: sh install_node.sh \n';
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

function INIT_FILE() {
#install conntrack-tools
   yum install -y conntrack-tools &>/dev/null
#install kubelet,kube-proxy
   LOG_PRINT INFO "Install Node Beginning"
   wget -c -P ${NODE_INSTALL_PATH} http://mirrors.longzhu.cn/src/kubernetes-1.11.2/kubernetes-node-linux-amd64.tar.gz &>/dev/null
   tar -xf ${NODE_INSTALL_PATH}/kubernetes-node-linux-amd64.tar.gz -C ${NODE_INSTALL_PATH} && cp ${NODE_INSTALL_PATH}/kubernetes/node/bin/{kubectl,kubelet,kube-proxy} /usr/local/bin/
   LOG_PRINT OK "Install Node Finish"
#kubelet
   swapoff -a
   cat ${RESOURCE_PATH}/config > ${CONFIG_FILE_PATH}/config
   LOG_PRINT OK "Create Config Is ${CONFIG_FILE_PATH}/config"
#因为参数淘汰的原因，需要将配置写入一个json文件中，下面创建配置json文件
   sed "s@NODE_IP@${NODE_IP}@g;s@DNS_IP@${CLUSTER_DNS_SVC_IP}@g" ${RESOURCE_PATH}/kubelet.config.json >${CONFIG_FILE_PATH}/kubelet.config.json
   sed "s@192.168.117.133@${NODE_IP}@g;s@HUB_ADDR@${DOCKER_REGISTRY}@g;s@NODE_DIR@${NODE_INSTALL_PATH}@g" ${RESOURCE_PATH}/kubelet >${CONFIG_FILE_PATH}/kubelet
   sed "s@/app/node@${NODE_INSTALL_PATH}@g" ${RESOURCE_PATH}/kubelet.service >/usr/lib/systemd/system/kubelet.service 
   systemctl daemon-reload
   systemctl enable kubelet.service &>/dev/null
   LOG_PRINT OK "Enable Kubelet"
#kube-proxy
   sed "s@192.168.117.133@${NODE_IP}@g;s@CLUSTER_CIDR@${CLUSTER_CIDR}@g" ${RESOURCE_PATH}/proxy >${CONFIG_FILE_PATH}/proxy
   cat ${RESOURCE_PATH}/kube-proxy.service >/usr/lib/systemd/system/kube-proxy.service
   systemctl daemon-reload
   systemctl enable kube-proxy.service &>/dev/null
   LOG_PRINT OK "Enable Kube-proxy"
}
function main() {
  stty erase ^H
  source $(pwd)/env.sh
  COUNT=0
  while (($COUNT < 1)) ;do
    read -p "Please Input This Node Ip: " NODE_IP
    LOG_PRINT OK "This Node Ip Is ${NODE_IP}"
    read -p "Are You sure That You Input is true? [Y/N]: " PARA
    if [[ $PARA == Y || $PARA == y ]];then
       COUNT=2
    else
       COUNT=0
    fi
  done
  mkdir $NODE_INSTALL_PATH -p
  RESOURCE_PATH=$(pwd)/resource
  INIT_FILE
  LOG_PRINT INFO "Now You Can Exec Script: systemctl start kubelet && systemctl start kube-proxy"
}

main
