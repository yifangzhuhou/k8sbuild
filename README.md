# 云原生

云原生是近些年来非常流行的概念，但是云原生具体含义是啥，众说纷纭，我翻阅了一些资料后，找到一个我能理解并且非常认同的说法，来源于华为官方在知乎上发布的一个帖子[什么是云原生？这回终于有人讲明白了][1]。

## 云原生起源

云原生的说法来自于英文词汇CloudNative，这是一个组合词，其中Cloud表示服务位于云中，Native表示服务原生为云而设计，适合在云上运行，充分利用和发挥云平台的弹性及分布式优势。 所以说云原生是一种构建和运行服务的方法论。

## 云原生特性

我感觉Pivotal公司对云原生特性的概括是非常精炼的，包括以下4点

1。 微服务

微服务大体是指以"高内聚，低耦合"为原则将服务按照功能进行切分，这样一来就可以非常方便地维护和变更子服务，而不会影响到整体服务的正常运行。 

2。 容器化

容器化为微服务提供实施保障，起到应用隔离的作用。 具体来说就是将服务与依赖环境一同打包到容器中，只需一键部署容器就能实现服务在不同平台上运行。 因为微服务化和集群化后的容器应用非常多，所以需要采取相应的技术对容器进行管理。 目前业界主流的容器化技术是[dokcer][2]+k8s，docker是应用最为广泛的容器引擎，k8s是google推出的容器编排系统。

3。 [DevOps][3]

Dev+Ops的组合词，即开发和运维，实际上还包括QA。它是一种开发流程，目的是让开发、运维和QA可以高效协作，为云原生提供持续交付能力。

4。 持续交付

持续交付是不误时开发，不停机更新，小步快跑，反传统瀑布式开发模型，这要求开发版本和稳定版本并存，其实需要很多流程和工具支撑。

# 搭建Kubernetes(k8s)集群

前公司基于docker+k8s实现了一套应用发布系统，公司内大大小小的服务都是依赖该系统进行部署维护的，功能如此强大让我对容器化技术产生了浓厚的兴趣，所以我决定从业界主流的k8s入手学习。
然而我条件有限，所以选择在本机上通过docker搭建k8s集群，大体思路是一个容器作为master节点运行control plane，其他容器以工作节点Node的角色运行。

## 环境要求

操作系统: Ubuntu 18.04.3 LTS
CPU: 8核
内存: 7.5G
Docker版本: 19.03.06

## 制作master镜像

**启动容器**

我习惯通过容器制作镜像，那么需要事先下载好基础镜像，因为docker默认从国外镜像源拉取，导致速度很慢，所以需要[更换成国内镜像源][4]。方法是在文件`/etc/docker/daemon.json`中添加以下内容 

```json
{
    "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"] //中科大镜像源
}
```

然后执行以下命令重启docker即可

```
sudo systemctl daemon-reload
sudo systemctl restart docker
```

这时我们先拉取镜像ubuntu:18.04，

```
sudo docker pull ubuntu:18.04
```

然后在该镜像基础上启动容器

```
sudo docker run -it -d --privileged=true --cap-add SYS_ADMIN --security-opt=seccomp:unconfined -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /var/lib/docker -v ~/workspace/src/k8s-learn:/tmp/config -p 30001:30001 --name k8s-master ubuntu:18.04 /sbin/init
```

这里稍微解释一下部分命令行参数的作用

| 参数                    | 作用                   |
|-------------------------|------------------------|
| --privileged=true -v /var/lib/docker       | 将宿主机目录`/var/lib/docker`挂载到容器内部，如果不这样做，容器内就无法运行docker引擎。[(参考资料)][5] |
| --cap-add SYS_ADMIN --security-opt=seccomp:unconfined -v /sys/fs/cgroup:/sys/fs/cgroup:ro /sbin/init | 在容器内给予systemd管理服务的权限，包括docker在内。[(参考资料)][6] | 
| -p 30001:30001          | 将宿主机端口30001映射到容器端口30001，从而访问到容器内的dashboard进行可视化管理k8s集群 |
| -v ~/workspace/src/k8s-learn/config:/tmp/config | 将宿主机的config目录挂载到容器内的/tmp/config，该目录存放初始化master节点的所需的配置文件及脚本，后续介绍 |


可以发现设置这些参数基本上是为了在master容器内安装并运行docker，这样k8s可以通过CRI与docker交互管理各种资源对象的容器。

**安装docker**

进入容器后执行下面命令安装docker

```
apt update && apt install docker.io & apt install systemd
```

编辑文件`/etc/docker/daemon.json`将默认镜像源更换成国内中科大的

```json
{
    "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"] //中科大镜像源
}
```

重启docker使更改生效

```
sudo systemctl daemon-reload
sudo systemctl restart docker
```

**安装k8s套件**

添加kubenetes的国内apt源，加快下载速度。

```
# 添加并信任APT证书
curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -
# 添加源地址
add-apt-repository "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main"
# 更新源并安装最新版 kubenetes， 版本号必须相同
sudo apt update && apt install -y kubelet=1.19.0-00 kubeadm=1.19.0-00 kubectl=1.19.0-00
```

**允许iptables检查桥接流量**

`lsmod | grep br_netfilter`确保`br_netfilter`模块被加载，如果没有可以通过`modprobe br_netfilter`显式加载。


执行以下命令确保iptables能正确查看桥接流量。

```
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

**关闭swap**

为了性能考虑，k8s需要关闭swap功能。

```
swapoff -a
```

**初始化master节点**

到这里所有准备工作完成，接下来使用kubeadm初始化master节点的control plane。

```
kubeadm init --kubernetes-version=v1.19.0 --pod-network-cidr=10.244.0.0/16 --image-repository='registry.cn-hangzhou.aliyuncs.com/google_containers'
```

对参数说明如下表

| 参数         | 说明           |
|--------------|----------------|
| --kubernetes-version=v1.19.0 | 指定control plane的版本   |
| --pod-network-cidr=10.244.0.0/16  | 因为选择flannel作为构建pod扁平化网络的插件，所以需要指定pod所属网段  |
| --image-repository='registry.cn-hangzhou.aliyuncs.com/google_containers' | 从阿里云镜像源下载control plane  |

将以下命令添加到文件~/.bashrc后执行`source ~/.bashrc`生效。

```
export KUBECONFIG=/etc/kubernetes/admin.conf
```

由于controller与scheduler的默认端口设置为0，导致无法k8s无法正常连接到这2个组件，`kubectl get cs`时显示`connection refused`错误，所以需要纠正后重启kubelet。

```
sed -i 's/- --port=0/\#- --port=0/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
sed -i 's/- --port=0/\#- --port=0/g' /etc/kubernetes/manifests/kube-scheduler.yaml
systemctl restart kubelet
```

**安装flannel网络插件**

还记得启动容器时我们将宿主机目录`~/workspace/src/k8s-learn/config`挂载到容器的`/tmp/config`上，该目录下存放了各种资源的配置文件，其中就包括[flannel][7]。
flannel的目的是构建一个扁平化网络空间，使得pod间直接相互通信。具体来说，就是让不同node上创建的pod具有全局唯一的虚拟ip地址，而且在这些ip之间建立一个
覆盖网络(overlay network)，通过该网络将数据包原封不动地传递到目标pod。这里我推荐看下[尚硅谷对k8s网络模型的讲解][8]。好了，让我们下面的命令安装flannel。

```
kubectl apply -f /tmp/config/flannel.yaml
```

安装完成后，执行`kubectl get pods --all-namespaces`观察control plane所有组件的运行状态，如果都是Running说明master初始化成功。

**安装dashboard**

Kubernetses dashboard是k8s集群的WEB UI管理工具，我们可以使用[官方配置文件][8]安装，但需要注意的是，集群外部应该能访问到dashboard，所以要设置成NodePort类型
的Service，通过端口30001暴露服务。

```
sed -i '160a\      nodePort: 30001' /tmp/config/dashboard.yaml
sed -i '157a\  type: NodePort' /tmp/config/dashboard.yaml
kubectl create -f /tmp/config/dashboard.yaml
```

之前启动容器时，我们已经将宿主机端口30001映射到容器的端口30001，但现在还需要[赋予ClusterRole权限][9]给集群才能访问到容器内的dashboard。

```
docker pull  mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.10.1
docker tag mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.10.1 k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1
kubectl create -f /tmp/config/dashboard-access.yaml
```

打开宿主机浏览器进入dashboard界面`https://127.0.0.1:30001`，选择通过token方式登录，token获取方式如下

```
kubectl get pods -n kube-system | grep dash | awk -F ' ' '{print $1}' | xargs kubectl describe -n kube-system pod | grep SecretName | grep token | awk -F ' ' '{print $2}' | xargs kubectl describe -n kube-system secret | grep token: | awk -F ' ' '{print $2}'
```

这样就可以通过web界面方便管理集群了。

**生成镜像**

`ctrl-d`退出容器，执行下面命令生成镜像k8s-master:0.0.1。

```
sudo docker commit -a ZhangLi -m "create k8s master" k8s-master k8s-master:0.0.1
```

[1]: https://zhuanlan.zhihu.com/p/150190166?utm_source=wechat_session
[2]: https://www.qikqiak.com/k8s-book/docs/2.Docker%20%E7%AE%80%E4%BB%8B.html
[3]: https://www.jianshu.com/p/c5d002cf25b9
[4]: https://blog.csdn.net/liu865033503/article/details/95936640
[5]: https://github.com/docker/for-linux/issues/230
[6]: https://blog.csdn.net/Q_AN1314/article/details/100093390
[7]: https://github.com/flannel-io/flannel#flannel
[8]: https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
[9]: https://blog.tekspace.io/kubernetes-dashboard-remote-access/
