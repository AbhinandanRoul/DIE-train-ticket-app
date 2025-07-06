#!/bin/bash

# minikube start --cpus 15 --memory 50000 --extra-config=controller-manager.horizontal-pod-autoscaler-downscale-stabilization=2m

# ISTIO COMMANDS
cd ~/istio-1.24.2
export PATH=$PWD/bin:$PATH

istioctl install -y

cd ~/DIE-train-ticket-app/
kubectl create -f <(istioctl kube-inject -f deployment/kubernetes-manifests/k8s-with-istio/ts-deployment-part1.yml)
kubectl create -f <(istioctl kube-inject -f deployment/kubernetes-manifests/k8s-with-istio/ts-deployment-part2.yml)
kubectl create -f <(istioctl kube-inject -f deployment/kubernetes-manifests/k8s-with-istio/ts-deployment-part3.yml)
kubectl apply  -f deployment/kubernetes-manifests/k8s-with-istio/trainticket-gateway.yaml

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/prometheus.yaml

# Jaeger
# cd ~/DIE-train-ticket-app/deployment/kubernetes-manifests/k8s-with-jaeger
# kubectl apply -f ts-deployment-part1.yml
# kubectl apply -f ts-deployment-part2.yml
# kubectl apply -f ts-deployment-part3.yml

cd ~/kube-prometheus/
kubectl apply --server-side -f manifests/setup/
kubectl apply -f manifests/

helm install kepler kepler/kepler  --namespace monitoring --set serviceMonitor.enabled=true  --set serviceMonitor.labels.release=prometheus-k8s

minikube addons enable metrics-server

# cd ~/DIE-train-ticket-app/
# kubectl apply -f quota.yaml --namespace=default

###################################################3
# minikube ssh
# sudo sysctl -w fs.inotify.max_user_watches=524288
# sudo sysctl -w fs.inotify.max_user_instances=512

#!/bin/bash

# Function to wait for all pods in a namespace with a specific label to be ready
wait_for_all_pods_ready() {
  namespace="$1"
  echo "Waiting for all pods in namespace '$namespace' to be ready..."

  # Wait until all pods are ready or timeout after 1200 seconds
  end=$((SECONDS+1200))
  while [ $SECONDS -lt $end ]; do
    not_ready=$(kubectl get pods -n "$namespace" --no-headers | grep -v "Running\|Completed" | wc -l)
    if [ "$not_ready" -eq 0 ]; then
      echo "All pods in namespace '$namespace' are ready."
      return 0
    fi
    sleep 5
  done

  echo "Timeout waiting for pods in namespace '$namespace' to be ready. Exiting..."
  exit 1
}

# Wait for Prometheus in the monitoring namespace
wait_for_all_pods_ready "monitoring"

# Start first screen session named 'port' and run the first port-forward command
screen -dmS port bash -c 'kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090'

# Wait for Prometheus in the istio-system namespace
wait_for_all_pods_ready "istio-system"

# Start second screen session named 'port2' and run the second port-forward command
screen -dmS port2 bash -c 'kubectl port-forward svc/prometheus 9091:9090 -n istio-system'

echo "Port-forwarding sessions started successfully."

wait_for_all_pods_ready "default"

echo "Done"