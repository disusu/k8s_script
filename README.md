# k8s_script
k8s自动安装脚本</br>
因为涉及到各种环境变量的自定义，所以脚本需要按照步骤执行，至于二进制文件默认是我的镜像仓库，如果自己已经下载好了在初始化变量的时候就回答y就好了</br>
第一步：下载脚本包
```
wget https://github.com/disusu/k8s_script/archive/1.0.0.tar.gz
```
第二步：进入目录先执行环境变量的初始化脚本
```
tar -xf 1.0.0.tar.gz
cd k8s_script-1.0.0/enviroment/
./
```