# k8s_script
k8s自动安装脚本</br>
因为涉及到各种环境变量的自定义，所以脚本需要按照步骤执行，至于二进制文件默认是我的镜像仓库，如果自己已经下载好了在初始化变量的时候就回答y就好了</br>
机器分配：（至少三台）</br>
机器一：master etcd kube-apiserver kube-scheduler kube-controller-manager</br>
机器二：node1 etcd kubelet kube-proxy</br>
机器三：node2 etcd kubelet kube-proxy</br>

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
第三步：初始化系统 创建秘钥(在master节点上)
```
cd k8s_script-1.0.0/master
./create_ssl_file.sh
```
