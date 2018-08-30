#!/bin/bash
#
# Filename: install_etcd.sh
# Date: Mon Aug 14 CST 2018
# Author: SuDi
# Email: i-disu@pptv.com
# Description: Interactive or Automatic Install etcd

if [ "$1" == "--help" ]; then
  printf -- 'Usage: sh install_etcd.sh \n';
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

#安装二进制文件到相应的目录
function INSTALL_EXEC() {
   wget -c -P ${ETCD_INSTALL_PATH} http://mirrors.longzhu.cn/src/etcd-3.3.8/etcd-v3.3.8-linux-amd64.tar.gz &>/dev/null 
   tar -xf ${ETCD_INSTALL_PATH}/etcd-v3.3.8-linux-amd64.tar.gz -C ${ETCD_INSTALL_PATH} && \
   cp ${ETCD_INSTALL_PATH}/etcd-v3.3.8-linux-amd64/{etcd,etcdctl} /usr/local/bin/
}

#初始化依赖文件
function INIT_FILE() {
   mkdir -p ${ETCD_INSTALL_PATH}
   mkdir -p ${ETCD_CONF_PATH}
   mkdir -p ${ETCD_DATA_PATH}
   printf "#[member]
ETCD_NAME="${NAME}"
ETCD_DATA_DIR="${ETCD_DATA_PATH}"
ETCD_LISTEN_PEER_URLS="https://${ETCD_LOCAL_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${ETCD_LOCAL_IP}:2379,http://127.0.0.1:2379"
#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${ETCD_LOCAL_IP}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://${ETCD_LOCAL_IP}:2379"
" >${ETCD_CONF_PATH}/etcd.conf

   printf '[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/app/ops/etcd/
EnvironmentFile=-/app/ops/etcd/etc/etcd.conf
ExecStart=/usr/local/bin/etcd \
--name ${ETCD_NAME} \
--cert-file=/etc/kubernetes/kubernetes.pem \
--key-file=/etc/kubernetes/kubernetes-key.pem \
--peer-cert-file=/etc/kubernetes/kubernetes.pem \
--peer-key-file=/etc/kubernetes/kubernetes-key.pem \
--trusted-ca-file=/etc/kubernetes/ca.pem \
--peer-trusted-ca-file=/etc/kubernetes/ca.pem \
--initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} \
--listen-peer-urls ${ETCD_LISTEN_PEER_URLS} \
--listen-client-urls ${ETCD_LISTEN_CLIENT_URLS} \
--advertise-client-urls ${ETCD_ADVERTISE_CLIENT_URLS} \
--initial-cluster-token ${ETCD_INITIAL_CLUSTER_TOKEN} \
--initial-cluster INITIAL_CLUSTER_IP \
--initial-cluster-state new \
--data-dir=${ETCD_DATA_DIR}
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
' >/usr/lib/systemd/system/etcd.service
   sed -i "s@/app/ops/etcd@${ETCD_INSTALL_PATH}@g" /usr/lib/systemd/system/etcd.service
   sed -i "s@INITIAL_CLUSTER_IP@${ETCD_NODES}@g" /usr/lib/systemd/system/etcd.service
   systemctl enable etcd &>/dev/null
}

#变量的初始化
function main() {
  stty erase ^H
  source $(pwd)/env.sh
  COUNT=0
  while (($COUNT < 1)) ;do
     read -p "Please Input This Node Ip: " NODE_IP
     LOG_PRINT OK "This Etcd Node Ip is $NODE_IP"

     read -p "Are You sure That You Input is true? [Y/N]: " PARA
     if [[ $PARA == Y || $PARA == y ]];then
        COUNT=2
     else
        COUNT=0
     fi
  done
  ETCD_CONF_PATH=${ETCD_INSTALL_PATH}/etc
  ETCD_DATA_PATH=${ETCD_INSTALL_PATH}/data
  if [[ $NODE_IP == $ETCD_IP_ONE ]];then
     NAME=etcd01
     ETCD_LOCAL_IP=$ETCD_IP_ONE
  elif [[ $NODE_IP == $ETCD_IP_TWO ]];then
     NAME=etcd02
     ETCD_LOCAL_IP=$ETCD_IP_TWO
  elif [[ $NODE_IP == $ETCD_IP_THREE ]];then
     NAME=etcd03
     ETCD_LOCAL_IP=$ETCD_IP_THREE
  fi
  INIT_FILE
  CHECK_STATUS "Init Etcd File"
  INSTALL_EXEC
  CHECK_STATUS "Install Etcd"
  LOG_PRINT OK "You Now already Install Etcd in $NAME Node"
  LOG_PRINT OK "Note: You Must Follow This etcd01=$ETCD_IP_ONE,etcd02=$ETCD_IP_TWO,etcd03=$ETCD_IP_THREE !!"
}
main
