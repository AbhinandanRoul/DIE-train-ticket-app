#!/bin/bash

cd ~/istio-1.24.1
export PATH=$PWD/bin:$PATH
istioctl install -f samples/bookinfo/demo-profile-no-gateways.yaml -y
kubectl label namespace default istio-injection=enabled
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.2.0" | kubectl apply -f -; }

cd ~/train-ticket/deployment/kubernetes-manifests/k8s-with-istio/
istioctl kube-inject -f ts-deployment-part1.yml > temp-part1.yml
kubectl create -f temp-part1.yml

istioctl kube-inject -f ts-deployment-part2.yml > temp-part2.yml
kubectl create -f temp-part2.yml

istioctl kube-inject -f ts-deployment-part3.yml > temp-part3.yml
kubectl create -f temp-part3.yml

kubectl apply  -f trainticket-gateway.yaml

cd ~/kube-prometheus/
kubectl apply --server-side -f manifests/setup/
kubectl apply -f manifests/

helm install kepler kepler/kepler  --namespace monitoring --set serviceMonitor.enabled=true  --set serviceMonitor.labels.release=prometheus-k8s

minikube addons enable metrics-server

cd ~/train-ticket/
kubectl apply -f quota.yaml --namespace=default
