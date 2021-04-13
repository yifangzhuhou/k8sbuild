# 组件说明

ApiServer: 所有服务的统一访问入口

ControlManager: 维持pod副本期望数目

Scheduler: 负载调度任务，选择合适的节点分配任务

Etcd: 分布式kv数据库，存储k8s集群所有重要信息(持久化)

Kubelet: 跟容器引擎(container runtime)交互实现容器的生命周期管理

Kube-proxy: 负责写入规则至iptables，ipvs实现服务映射访问

CoreDNS: 负责k8s集群中service的域名解析

Dashboard: web ui管理工具，给k8s集群提供一个B/S结构的访问体系

Ingress Conttoller: 官方只提供4层负载均衡，可以实现7层负载均衡

Fedetation: 提供跨集群中心多k8s管理功能

Prometheus: 为k8s集群提供监控能力

ELK: 提供k8s集群日志统一分析接入平台


# Pod概念

1. 自主pod

2. 控制器管理的pod

pod中所有业务容器共享pause容器的网络协议栈和存储卷

1. ReplicationController: 用来保持期望的pod数量，即如果有pod异常退出，会自动创建新pod替换，有多出的pod也会自动回收
2.  ReplicatSet: 新版本k8s中代替ReplicationController，支持集合式selector
3. Deployment: 管理ReplicaSet，这样避免跟其他机制的不兼容，例如Deployment支持Rolling-Update而ReplicaSet不支持

Horizontal Pod Autoscaling: 仅适用于RS和Deployment，支持根据metric实现pod的弹性扩缩容

StatefulSet: 解决有状态服务问题，应用场景如下
   - 稳定的持久化存储，即pod重新调度仍能访问到相同的持久化数据，基于PVC实现
   - 稳定的网络标志，即pod重新调度后其PodName和HostName不变
   - 有序部署，有序扩展
   - 有序收缩，有序删除

DaemonSet: 确保全部(或部分)node上运行一个指定的pod副本。添加pod到集群中的新node上，回收集群中已删除node上的pod。应用场景如下
   - 在所有node上运行监控daemon，例如Prometheus Node Exporter
   - 在所有node上运行日志收集daemon，例如fluentd、logstash
   - 运行集群存储daemon，例如glusterd、ceph

Job: 负责批处理任务，保证批处理任务在一个或多个pod上成功结束

CronJob: 管理基于时间的的Job，即
   - 在指定时间点只运行一次
   - 周期性地在指定时间点执行

# 网络模型

k8s网络模型假设所有pod都处在一个可以直连的扁平化网络空间中，为了实现这个假设，需要将不同node上的pod间的互相访问打通

## 网络通信方式

同pod下各容器间: lo

同node下各pod: docker0直接转发

不同node下各pod: overlay network

pod与service间: 各node的iptables规则

Flannel: CoreOS开发，网络规划服务。为不同node分配全局唯一的vip，以这些vip为基础构建覆盖网络(Overlay Network)，实现将数据包从源pod发送到目的pod

etcd与Flannel间关系: 
   - etcd存储管理Flannel可分配的ip地址段资源
   - Flannel监控etcd中所有pod的ip地址，在内存中建立维护pod到node的路由表

# 资源类型

k8s中所有内容都被抽象为资源，实例化后称为对象

## 资源分类

### 命名空间级别

工作负载型资源(workload): Pod, ReplicaSet, Deployment等

服务发现及负载均衡型资源(ServiceDiscovery & LoadBalance): Service, Ingress

配置与存储型资源: Volume(存储卷)，CSI(容器存储接口，扩展各种第三方存储卷)                                                  

特殊类型资源: ConfigMap，Secret

### 集群级别

Namespace Node Role ClusterRole RoleBinding ClusterRoleBinding

### 元数据级别

HPA PodTemplate LimitRange


# 资源清单

yaml格式

资源对象文档格式说明 kubectl explain

# pod生命周期

kubectl---->api-server--(etcd)-->kubelet--(cri)-->container runtime---->init C---->main C

                                                                                   ------------liveness--------------

                                                                                   --start--

                                                                                            --readness--

                                                                                                             --stop--


pod可能具有多个容器，应用运行在容器中，但是它可能有一个或多个先于应用容器启动的init容器(init C)。

init容器与普通容器相似，除以下
  - init容器总是运行到成功完成为止
  - 每个init容器必须在上一个init容器成功完成后才能启动(串行同步)

如果init容器失败，k8s将一直重启pod，直到init容器成功为止，但是如果pod的restartPolicy为never，则不会重新启动

# 探针

## 探针类型

探针是由kubele对容器进行的定期诊断。要执行诊断，kubelet调用由容器实现的handler，有三种类型
  - ExecAction: 在容器内执行指定命令，命令返回码为0表示诊断成功
  - TCPSocketAction: 在指定ip:port上进行tcp检测，如果端口打开表示诊断成功
  - HTTPGetAction: 在指定ip:port上进行http get请求，如果响应状态码大于等于200小于400则表示诊断成功

## 探测结果

  成功、失败和未知

## 探测方式

livenessProbe: 指示容器是否正在运行，如果探测失败，则kubelet杀死容器，并且容器将受到重启策略的影响，如果容器不提供存活探针，则默认状态为success

readinessProbe: 指示容器是否准备好提供服务，如果探测失败，端点控制器将从pod匹配的所有service中删除该pod。初始延迟之前的就绪状态默认为failure，
如果容器不提供就绪探针，则默认状态为success

# Service

## ClusterIP

默认类型，创建一个vip和端口仅供集群内部访问该服务

## NodePort

以ClusterIP为基础，在每个Node上开放NodePort供外部访问到该服务

## LoadBalancer

以NodePort为基础，借助云供应商创建负载均衡器，将请求转发到NodeIP:NodePort上

## ExternalName

将集群外部服务引入到集群内部使用

# Ingress

从前面学习可知k8s常见的暴露服务方式，但是存在以下问题

## Pod漂移

k8s能够在任意时刻维持期望数量的Pod副本，也就是说，挂掉的Pod可能在其他Node上创建，多余的Node会被回收，随着Pod的创建与销毁，Pod ip也必然发生变化，那么如何将Pod ip的动态变化暴露给外部？
这里可以借助NodePort类型的Service机制实现，它根据Label选定一组Pod，并监控和自动负载这些Pod ip，那么只需向外暴露Service vip就足够了。它会在每个Node上开启端口接收外部流量并转发到内部Pod上。

## 端口管理

NodePort Service存在一个缺陷是，当需要暴露的服务越来越多时，在Node上开启的端口也就越来越多，导致难以管理维护这些端口。那么我们可以考虑只创建一个NodePort Service，其中运行Nginx Pod，它是
外部访问的唯一入口，基于域名和访问路径将请求转发到对应的集群内部Service上。

## 域名分配及动态更新

如果后续有其他服务陆续加入集群并需要暴露给外部访问，那么需要添加路由规则至Nginx配置后生成新的Nginx镜像，滚动更新Nginx Pod才能实现。这种做法未免太过麻烦。为了方便管理和更新配置，[Ingress][1]应运而生。

## Ingress及Ingress Controller

你可以利用Ingress对象编写路由规则，再由Ingress Controller与ApiServer交互监听到Ingress的规则变化，并生成对应的Nginx配置，更新到Nginx Pod中。
可以看出，Ingress是一组规则的集合，扮演着Nginx配置的角色，而Ingress Controller则负责服务发现，反向代理和负载均衡。

[1]: https://www.cnblogs.com/linuxk/p/9706720.html
