#!/bin/bash
# Filename: init_env.sh
# Date: Mon Aug 23 CST 2018
# Author: SuDi
# Email: i-disu@pptv.com
# Description: Init K8s Enviroument

if [ "$1" == "--help" ]; then
  printf -- 'Usage: sh init_env.sh  {--auto|--control} \n
--auto     Parameter is to choose the default setting \n--control  The parameter is set by yourself \n';
  exit 0;
fi

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin


arg=$1

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

function OUT_ENV() {
   local CONTENT=$1
   echo "$CONTENT" >>$(pwd)/env.sh
}

function MUST_INPUT() {
  echo '#!/bin/bash' >$(pwd)/env.sh
  COUNT=0
  while (($COUNT < 1)) ;do
   read -p "Please Input Master Ip: " MASTER_IP
   if [[ -z "$MASTER_IP" ]];then
     LOG_PRINT ERROR "Please Input Your Master Ip !!"
     break
   else
     LOG_PRINT OK "Master Ip Is $MASTER_IP"
   fi
   OUT_ENV "MASTER_IP=$MASTER_IP"

   read -p "Please Input Docker Hub Address(eg:hub.xxx.cn): " DOCKER_REGISTRY
   LOG_PRINT OK "Docker Hub Address Is $DOCKER_REGISTRY"
   OUT_ENV "DOCKER_REGISTRY=$DOCKER_REGISTRY"

   read -p "Please Input Etcd Three Node Ip(eg:172.12.xx,172.12.xx,172.12.xx): " ETCD_IPS
   LOG_PRINT OK "Etcd Three Node Ip Is $ETCD_IPS"
   ETCD_IP_ONE=$(echo $ETCD_IPS |cut -d , -f 1)
   OUT_ENV "ETCD_IP_ONE=$ETCD_IP_ONE"

   ETCD_IP_TWO=$(echo $ETCD_IPS |cut -d , -f 2)
   OUT_ENV "ETCD_IP_TWO=$ETCD_IP_TWO"

   ETCD_IP_THREE=$(echo $ETCD_IPS |cut -d , -f 3)
   OUT_ENV "ETCD_IP_THREE=$ETCD_IP_THREE"

   ETCD_ENDPOINTS="'https://${ETCD_IP_ONE}:2379,https://${ETCD_IP_TWO}:2379,https://${ETCD_IP_THREE}:2379'"
   ETCD_NODES="'etcd01=https://${ETCD_IP_ONE}:2380,etcd02=https://${ETCD_IP_TWO}:2380,etcd03=https://${ETCD_IP_THREE}:2380'"
   OUT_ENV "ETCD_ENDPOINTS=$ETCD_ENDPOINTS"
   OUT_ENV "ETCD_NODES=$ETCD_NODES"

   OUT_ENV "MANAGER_IP=$MASTER_IP"
   OUT_ENV "SCHEDULER_IP=$MASTER_IP"

   read -p "Are You sure That You Input is true? [Y/N]: " PARA
   if [[ $PARA == Y || $PARA == y ]];then
      COUNT=2
   else
      COUNT=0
   fi
  done
}

function NOT_MUST_INPUT() {
  COUNT=0
  while (($COUNT < 1)) ;do
   LOG_PRINT INFO "About Address......"

   read -p "Please Input Service CIDR(eg:172.12.xx.xx/16): " SERVICE_CIDR
   LOG_PRINT OK "Service CIDR is $SERVICE_CIDR"
   SVC_TMP_IP=`echo $SERVICE_CIDR | cut -d "." -f 1,2,3`
   CLUSTER_KUBERNETES_SVC_IP="${SVC_TMP_IP}.1"
   CLUSTER_DNS_SVC_IP="${SVC_TMP_IP}.2"
   OUT_ENV "SERVICE_CIDR=$SERVICE_CIDR"
   OUT_ENV "CLUSTER_KUBERNETES_SVC_IP=$CLUSTER_KUBERNETES_SVC_IP"
   OUT_ENV "CLUSTER_DNS_SVC_IP=$CLUSTER_DNS_SVC_IP"

   read -p "Please Input Cluster CIDR(eg:172.13.xx.xx/16): " CLUSTER_CIDR
   LOG_PRINT OK "Cluster CIDR is $CLUSTER_CIDR"
   OUT_ENV "CLUSTER_CIDR=$CLUSTER_CIDR"

   LOG_PRINT INFO "About Install Path......"

   read -p "Please Input Etcd Install Path: " ETCD_INSTALL_PATH
   LOG_PRINT OK "Etcd Install Path Is $ETCD_INSTALL_PATH"
   OUT_ENV "ETCD_INSTALL_PATH=$ETCD_INSTALL_PATH"

   read -p "Please Input Master Install Path: " MASTER_INSTALL_PATH
   LOG_PRINT OK "Master Install Path Is $MASTER_INSTALL_PATH"
   OUT_ENV "MASTER_INSTALL_PATH=$MASTER_INSTALL_PATH"

   read -p "Please Input Client Install Path: " CLIENT_INSTALL_PATH
   LOG_PRINT OK "Client Install Path Is $CLIENT_INSTALL_PATH"
   OUT_ENV "CLIENT_INSTALL_PATH=$CLIENT_INSTALL_PATH"

   read -p "Please Input Node Install Path: " NODE_INSTALL_PATH
   LOG_PRINT OK "Node Install Path Is $NODE_INSTALL_PATH"
   OUT_ENV "NODE_INSTALL_PATH=$NODE_INSTALL_PATH"

   read -p "Please Input Flanneld Install Path: " FLANNELD_INSTALL_PATH
   LOG_PRINT OK "Flanneld Install Path Is $FLANNELD_INSTALL_PATH"
   OUT_ENV "FLANNELD_INSTALL_PATH=$FLANNELD_INSTALL_PATH"
   
   CSR_JSON_PATH="$(pwd)/ssl_source"
   OUT_ENV "CSR_JSON_PATH=$CSR_JSON_PATH"

   CONFIG_FILE_PATH="/etc/kubernetes"
   OUT_ENV "CONFIG_FILE_PATH=$CONFIG_FILE_PATH"
   
   read -p "Are You sure That You Input is true? [Y/N]: " PARA
   if [[ $PARA == Y || $PARA == y ]];then
      COUNT=2
   else
      COUNT=0
   fi
  done
}

function DEFAULT_INPUT() {
   SERVICE_CIDR="172.17.0.0/16"
   OUT_ENV "SERVICE_CIDR=$SERVICE_CIDR"
   
   CLUSTER_CIDR="172.18.0.0/16"
   OUT_ENV "CLUSTER_CIDR=$CLUSTER_CIDR"

   CLUSTER_KUBERNETES_SVC_IP="172.17.0.1"
   OUT_ENV "CLUSTER_KUBERNETES_SVC_IP=$CLUSTER_KUBERNETES_SVC_IP"

   CLUSTER_DNS_SVC_IP="172.17.0.2"
   OUT_ENV "CLUSTER_DNS_SVC_IP=$CLUSTER_DNS_SVC_IP"

   ETCD_INSTALL_PATH="/app/etcd"
   OUT_ENV "ETCD_INSTALL_PATH=$ETCD_INSTALL_PATH"

   MASTER_INSTALL_PATH="/app/kubernetes"
   OUT_ENV "MASTER_INSTALL_PATH=$MASTER_INSTALL_PATH"

   CLIENT_INSTALL_PATH="/app/client"
   OUT_ENV "CLIENT_INSTALL_PATH=$CLIENT_INSTALL_PATH"

   FLANNELD_INSTALL_PATH="/app/flanneld"
   OUT_ENV "FLANNELD_INSTALL_PATH=$FLANNELD_INSTALL_PATH"

   NODE_INSTALL_PATH="/app/node"
   OUT_ENV "NODE_INSTALL_PATH=$NODE_INSTALL_PATH"
   
   CSR_JSON_PATH="$(pwd)/ssl_source"
   OUT_ENV "CSR_JSON_PATH=$CSR_JSON_PATH"
   
   CONFIG_FILE_PATH="/etc/kubernetes"
   OUT_ENV "CONFIG_FILE_PATH=$CONFIG_FILE_PATH"
}

function main() {
  stty erase ^H
  if [[ $arg == '--auto' || $arg == '' ]];then
     MUST_INPUT
     DEFAULT_INPUT
     
  elif [[ $arg == '--control' ]];then
     MUST_INPUT
     NOT_MUST_INPUT
  fi
}

main
