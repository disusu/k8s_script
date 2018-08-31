#!/bin/bash
#
# Filename: create_ssl_file.sh
# Date: Mon Aug 13 CST 2018
# Author: SuDi
# Email: i-disu@pptv.com
# Description: Interactive or Automatic create ssl file

if [ "$1" == "--help" ]; then
  printf -- 'Usage: sh create_ssl_file.sh\n';
  exit 0;
fi

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

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

function INSTALL_CFSSL() {
   LOG_PRINT INFO "Beginning Install Cfssl Tools......"
   yum install -y wget &>/dev/null
   wget -c -P ${CLIENT_INSTALL_PATH} https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 &>/dev/null && chmod +x ${CLIENT_INSTALL_PATH}/cfssl_linux-amd64 && mv ${CLIENT_INSTALL_PATH}/cfssl_linux-amd64 /usr/local/bin/cfssl
   CHECK_STATUS "Install cfssl"
   wget -c -P ${CLIENT_INSTALL_PATH} https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 &>/dev/null && chmod +x ${CLIENT_INSTALL_PATH}/cfssljson_linux-amd64 && mv ${CLIENT_INSTALL_PATH}/cfssljson_linux-amd64 /usr/local/bin/cfssljson
   CHECK_STATUS "Install cfssljson"
   wget -c -P ${CLIENT_INSTALL_PATH} https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64  &>/dev/null && chmod +x ${CLIENT_INSTALL_PATH}/cfssl-certinfo_linux-amd64 && mv ${CLIENT_INSTALL_PATH}/cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
   CHECK_STATUS "Install cfssl-certinfo"
}

function INSTALL_EXEC() {
   if [[ $INSTALL == YES ]];then
    LOG_PRINT INFO "Beginning Install Kubectl......"
    wget -c -P ${CLIENT_INSTALL_PATH} http://mirrors.dilinux.cn/src/1.11.2/kubernetes-client-linux-amd64.tar.gz &>/dev/null
    tar -xf ${CLIENT_INSTALL_PATH}/kubernetes-client-linux-amd64.tar.gz -C ${CLIENT_INSTALL_PATH}
    cp ${CLIENT_INSTALL_PATH}/kubernetes/client/bin/kubectl /usr/local/bin/
    CHECK_STATUS "Install Kubectl Exec File"
   else
    LOG_PRINT INFO "You Already Installed Kubectl"
    sleep 5
   fi
}

function CREATE_TLS() {
   LOG_PRINT INFO "Beginning Create Ssl File......"
#替换ip
   sed "s@CLUSTER_KUBERNETES_SVC_IP@${CLUSTER_KUBERNETES_SVC_IP}@g;s@MASTER_IP@${MASTER_IP}@g;s@ETCD_IP_ONE@${ETCD_IP_ONE}@g;s@ETCD_IP_TWO@$ETCD_IP_TWO@g;s@ETCD_IP_THREE@${ETCD_IP_THREE}@g" <${CSR_JSON_PATH}/kubernetes-tmp.json >${CSR_JSON_PATH}/kubernetes-csr.json
   sed "s@MANAGER_IP@${MANAGER_IP}@g" <${CSR_JSON_PATH}/kube-controller-manager-tmp.json >${CSR_JSON_PATH}/kube-controller-manager-csr.json
   sed "s@SCHEDULER_IP@${SCHEDULER_IP}@g" <${CSR_JSON_PATH}/kube-scheduler-tmp.json >${CSR_JSON_PATH}/kube-scheduler-csr.json
#创建CA证书和私钥（后续认证都会用到）
   `cfssl gencert -initca ${CSR_JSON_PATH}/ca-csr.json | cfssljson -bare ${CONFIG_FILE_PATH}/ca` &>/dev/null #生成 CA 证书和私钥
   CHECK_STATUS "Create CA 证书和私钥"
#这里用个for循环吧，创建相应的凭证和私钥,*.pem
   for JSON_FILE in `echo admin kube-proxy kubernetes kube-controller-manager kube-scheduler`
   do
     cfssl gencert -ca=${CONFIG_FILE_PATH}/ca.pem -ca-key=${CONFIG_FILE_PATH}/ca-key.pem -config=${CSR_JSON_PATH}/ca-config.json  -profile=kubernetes ${CSR_JSON_PATH}/${JSON_FILE}-csr.json | cfssljson -bare ${CONFIG_FILE_PATH}/${JSON_FILE} &>/dev/null #创建 kubectl kube-proxy kubernetes client  凭证和私钥 
     CHECK_STATUS "Create ${JSON_FILE} client 凭证和私钥"
   done
}

function CREATE_TOKEN() {
    echo "${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:bootstrappers"" >${CONFIG_FILE_PATH}/token.csv
    CHECK_STATUS "Create TOKEN"
}

function KUBECTL_KUBECONFIG() {
    kubectl config set-cluster kubernetes --certificate-authority=${CONFIG_FILE_PATH}/ca.pem --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${CONFIG_FILE_PATH}/kubectl.kubeconfig &>/dev/null
    kubectl config set-credentials admin --client-certificate=${CONFIG_FILE_PATH}/admin.pem --embed-certs=true --client-key=${CONFIG_FILE_PATH}/admin-key.pem --kubeconfig=${CONFIG_FILE_PATH}/kubectl.kubeconfig &>/dev/null
    kubectl config set-context kubernetes --cluster=kubernetes --user=admin --kubeconfig=${CONFIG_FILE_PATH}/kubectl.kubeconfig &>/dev/null
    kubectl config use-context kubernetes --kubeconfig=${CONFIG_FILE_PATH}/kubectl.kubeconfig &>/dev/null
#copy kubeconfig to kubectl default read file
    mkdir -p ~/.kube
    cp ${CONFIG_FILE_PATH}/kubectl.kubeconfig ~/.kube/config
}

function KUBELET_KUBECONFIG() {
    kubectl config set-cluster kubernetes --certificate-authority=${CONFIG_FILE_PATH}/ca.pem --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${CONFIG_FILE_PATH}/bootstrap.kubeconfig &>/dev/null
    kubectl config set-credentials kubelet-bootstrap --token=${BOOTSTRAP_TOKEN} --kubeconfig=${CONFIG_FILE_PATH}/bootstrap.kubeconfig &>/dev/null
    kubectl config set-context default --cluster=kubernetes --user=kubelet-bootstrap --kubeconfig=${CONFIG_FILE_PATH}/bootstrap.kubeconfig &>/dev/null
    kubectl config use-context default --kubeconfig=${CONFIG_FILE_PATH}/bootstrap.kubeconfig &>/dev/null
}

function KUBE_PROXY_KUBECONFIG() {
    kubectl config set-cluster kubernetes --certificate-authority=${CONFIG_FILE_PATH}/ca.pem --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${CONFIG_FILE_PATH}/kube-proxy.kubeconfig &>/dev/null
    # 设置客户端认证参数
    kubectl config set-credentials kube-proxy --client-certificate=${CONFIG_FILE_PATH}/kube-proxy.pem --client-key=${CONFIG_FILE_PATH}/kube-proxy-key.pem --embed-certs=true --kubeconfig=${CONFIG_FILE_PATH}/kube-proxy.kubeconfig &>/dev/null
    # 设置上下文参数
    kubectl config set-context default --cluster=kubernetes --user=kube-proxy --kubeconfig=${CONFIG_FILE_PATH}/kube-proxy.kubeconfig &>/dev/null
   # 设置默认上下文
    kubectl config use-context default --kubeconfig=${CONFIG_FILE_PATH}/kube-proxy.kubeconfig &>/dev/null
}

function MANAGER_SCHEDULER_KUBECONFIG() {
  for COMPONENT in `echo kube-controller-manager kube-scheduler`
  do
   kubectl config set-cluster kubernetes --certificate-authority=${CONFIG_FILE_PATH}/ca.pem --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${CONFIG_FILE_PATH}/${COMPONENT}.kubeconfig &>/dev/null
   kubectl config set-credentials system:${COMPONENT} --client-certificate=${CONFIG_FILE_PATH}/${COMPONENT}.pem --client-key=${CONFIG_FILE_PATH}/${COMPONENT}-key.pem --embed-certs=true --kubeconfig=${CONFIG_FILE_PATH}/${COMPONENT}.kubeconfig &>/dev/null
   kubectl config set-context system:${COMPONENT} --cluster=kubernetes --user=system:${COMPONENT} --kubeconfig=${CONFIG_FILE_PATH}/${COMPONENT}.kubeconfig &>/dev/null
   kubectl config use-context system:${COMPONENT} --kubeconfig=${CONFIG_FILE_PATH}/${COMPONENT}.kubeconfig &>/dev/null
   CHECK_STATUS "Create ${COMPONENT}.kubeconfig"
  done
}

#创建kubeconfig文件
function CREATE_KUBECONFIG() {
   LOG_PRINT INFO "Beginning Create Kubeconfig File......"
   KUBECTL_KUBECONFIG 
   CHECK_STATUS "Create KUBECTL_KUBECONFIG"
   KUBELET_KUBECONFIG  
   CHECK_STATUS "Create KUBELET_KUBECONFIG"
   KUBE_PROXY_KUBECONFIG 
   CHECK_STATUS "Create KUBE_PROXY_KUBECONFIG"
   MANAGER_SCHEDULER_KUBECONFIG
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
       mkdir -p $CLIENT_INSTALL_PATH && mkdir -p $CONFIG_FILE_PATH
       COUNT=2
    else
       COUNT=0
    fi
  done
  BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
  KUBE_APISERVER="https://${MASTER_IP}:6443" #声明master apiserver地址
  INSTALL_CFSSL
  INSTALL_EXEC
  CREATE_TLS
  CREATE_TOKEN
  CREATE_KUBECONFIG
  LOG_PRINT OK "Note: Ssl File Information:" 
  find $CONFIG_FILE_PATH -type f
  tar -zcPf /tmp/ca-file.tar.gz /etc/kubernetes
  LOG_PRINT OK "Note: Now You Must Send Tar /tmp/ca-file.tar.gz To Other Node And Exec 'tar -xPf ca-file.tar.gz'"
}
main
