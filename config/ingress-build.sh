#!/bin/bash

set -xe

SVC_PATH=/tmp/config/service
INGRESS_PATH=/tmp/config/ingress-nginx

kubectl apply -f $SVC_PATH/myapp-deploy.yaml && kubectl apply -f $SVC_PATH/myapp-service.yaml

kubectl apply -f $INGRESS_PATH/ingress-nginx-controller.yaml 

sleep 30

kubectl apply -f $INGRESS_PATH/ingress.yaml 
