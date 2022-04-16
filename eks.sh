#!/usr/bin/env bash

export AWS_DEFAULT_REGION="eu-west-1"

aws eks update-kubeconfig --name mikosins-test
kubectl create namespace eks-sample-app
kubectl apply -f eks-sample-deployment.yaml
kubectl apply -f eks-sample-service.yaml
kubectl get all -n eks-sample-app
kubectl -n eks-sample-app describe service eks-sample-linux-service
kubectl -n eks-sample-app describe pod eks-sample-linux-deployment-65b7669776-m6qxz
kubectl exec -it eks-sample-linux-deployment-65b7669776-m6qxz -n eks-sample-app -- /bin/bash
curl eks-sample-linux-service

#kubectl get pods -n kube-system -o wide
#kubectl get pods -n eks-sample-app -o wide
#
#kubectl patch deployment coredns \
#    -n kube-system \
#    --type json \
#    -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
#
#kubectl rollout restart -n kube-system deployment coredns
