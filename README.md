# k8s_script
k8s自动安装脚本</br>
因为涉及到各种环境变量的自定义，所以脚本需要按照步骤执行，至于二进制文件默认是我的镜像仓库，如果自己已经下载好了在初始化变量的时候就回答y就好了</br>
机器分配：（至少三台）</br>
机器一：master etcd kube-apiserver kube-scheduler kube-controller-manager</br>
机器二：node1 etcd kubelet kube-proxy</br>
机器三：node2 etcd kubelet kube-proxy</br>

在master节点上执行下面步骤:</br>
第一步：下载脚本包
```
wget https://github.com/disusu/k8s_script/archive/1.0.0.tar.gz
```
第二步：进入目录先执行环境变量的初始化脚本
```
tar -xf 1.0.0.tar.gz
cd k8s_script-1.0.0/enviroment/
./init_env.sh --auto(有些变量为默认值) 或者 ./init_env.sh --control(变量为自定义) #会生成一个env.sh文件（重要）
cp env.sh ../etcd/ && cp env.sh ../master/ && cp env.sh ../node/ #将生成的全局环境变量文件拷贝到相应的工作目录夹
```
第三步：初始化系统并创建秘钥(在master节点上，注意env.sh要在安装目录下)
```
cd k8s_script-1.0.0/master
./init_system.sh #初始化系统、执行完之后会自动重启
./create_ssl_file.sh #生成秘钥
执行完会在当前目录下的ca-file目录下生成一个秘钥的tar包，需要将该tar包解压到相应的节点，注意使用tar的解压参数为'-xPf' !!(以后增加节点需要先前解压改tar包)
```
至此，上述工作做完之后环境变量、认证的证书都已经准备完毕</br>

在etcd节点上执行安装etcd的脚本（需要三个节点，注意env.sh要在安装目录下）：
```
cd k8s_script-1.0.0/etcd
./init_system.sh #初始化系统，如果已经初始化过的就不用执行该脚本了
./install_etcd.sh #安装etcd，注意要将三个节点都安装之后再启动才会正常，因为etcd也依赖的证书，所以需要在改节点解压证书的tar包
```
一定要注意：等etcd状态正常才可以后续操作，etcd作为存储是很重要的
```
etcdctl \
  --ca-file=/etc/kubernetes/ca.pem \
  --cert-file=/etc/kubernetes/kubernetes.pem \
  --key-file=/etc/kubernetes/kubernetes-key.pem \
  cluster-health #检查etcd的集群健康
```
etcd启动之后开始安装k8s主要的组件:</br>
在master节点上执行安装master的脚本（目前是单节点，注意env.sh要在安装目录下）：
```
cd k8s_script-1.0.0/master
./install_master.sh #执行完毕之后启动三个master组件
```
在node节点上执行安装flannel、kubelet和kube-proxy组件(注意env.sh要在安装目录下)
```
cd k8s_script-1.0.0/node
./init_system.sh #初始化系统，已经初始化的就不用执行了
./install_flannel.sh #安装flannel,并直接启动flannel和docker
./install_node.sh #安装node组件，然后启动kubelet、kube-proxy
```
