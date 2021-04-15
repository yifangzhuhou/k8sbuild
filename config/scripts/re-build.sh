#!/bin/bash

set -xe

K8S_MANIFEST=/etc/kubernetes/manifests

DASHBOARD_PATH=/tmp/config/dashboard

#mv /lib/modules/*-generic /lib/modules/`uname -r`

#mv /boot/config* /boot/config-`uname -r`

kubeadm reset

swapoff -a

kubeadm init --kubernetes-version=v1.19.0 --pod-network-cidr=10.244.0.0/16 --image-repository='registry.cn-hangzhou.aliyuncs.com/google_containers'

sed -i 's/- --port=0/\#- --port=0/g' $K8S_MANIFEST/kube-controller-manager.yaml

sed -i 's/- --port=0/\#- --port=0/g' $K8S_MANIFEST/kube-scheduler.yaml

systemctl restart kubelet

kubectl apply -f /tmp/config/flannel.yaml

sed -i '160a\      nodePort: 30001' $DASHBOARD_PATH/dashboard.yaml

sed -i '157a\  type: NodePort' $DASHBOARD_PATH/dashboard.yaml

docker pull  mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.10.1

docker tag mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.10.1 k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1

kubectl create -f $DASHBOARD_PATH/dashboard.yaml

kubectl create -f $DASHBOARD_PATH/dashboard-access.yaml

sed -i '/nodePort: 30001/d' $DASHBOARD_PATH/dashboard.yaml

sed -i '/type: NodePort/d' $DASHBOARD_PATH/dashboard.yaml

#kubectl get pods -n kube-system | grep dash | awk -F ' ' '{print $1}' | xargs kubectl describe -n kube-system pod | grep SecretName | grep token | awk -F ' ' '{print $2}' | xargs kubectl describe -n kube-system secret | grep token: | awk -F ' ' '{print $2}'
