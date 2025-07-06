#!/bin/bash

# --- Configuration ---
STGCN_IP="192.168.1.76"
JUMP_HOST_IP="192.168.1.18"
LOCUST_IP="192.168.1.146"
REMOTE_PATH_STGCN="/home/ubuntu/Carbon-Aware-AutoScaler/DeepScaler"
REMOTE_PATH_LOCUST="~/evaluation"
SSH_KEY_PATH="~/Carbon-Aware-AutoScaler/DeepScaler/train.pem"

# Define your models, IDs, and numeric restrictions
#MODEL_NAMES=("AdapGLD" "AdapGLD" "AdapGLD" "AdapGLD" "AdapGLA" "AdapGLA" "AdapGLA" "AdapGLA")
#MODEL_IDS=("AdapGLD_fresh" "AdapGLD_fresh" "AdapGLD_fresh" "AdapGLD_fresh" "AdapGLA_fresh" "AdapGLA_fresh" "AdapGLA_fresh" "AdapGLA_fresh")
MODEL_NAMES=("HPA")
MODEL_IDS=("Hpa")
MODEL_RESTRICTIONS=(0.35 0.4 0.5 0.8)  # Numeric restrictions

START_ROUND=0
MAX_ROUND=10  # Set the last round number here
SAVE_DIR="./saved_images"

# Iterate over all models
for (( MODEL_IDX=0; MODEL_IDX<${#MODEL_NAMES[@]}; MODEL_IDX++ ))
do
  MODEL_NAME=${MODEL_NAMES[MODEL_IDX]}
  MODEL_ID=${MODEL_IDS[MODEL_IDX]}
  MODEL_RESTRICTION=${MODEL_RESTRICTIONS[MODEL_IDX]}

  for (( ROUND=$START_ROUND; ROUND<=MAX_ROUND; ROUND++ ))
  do
    # --- Step 1: Local - Start Minikube and deploy Istio ---
    echo "[Local] Starting Minikube..."
    minikube start --cpus 15 --memory 50000

    echo "[Local] Set environment to use Minikube Docker daemon"
    # eval $(minikube docker-env)

    echo "[Local] Load locally saved docker images into Minikube Docker daemon"
    #for image_tar in "$SAVE_DIR"/*.tar; do
    #  if [ -f "$image_tar" ]; then
    #    echo "Loading image $image_tar into Docker..."
    #    docker load -i "$image_tar" || { echo "Failed to load $image_tar"; continue; }
    #  else
    #    echo "No .tar files found in $SAVE_DIR."
    #    break
    #  fi
    #done

    echo "[Local] Deploying Istio..."
    bash deploy_istio.sh
    bash hpa_all.sh

    # --- Step 3: Locust - Start load test ---
    echo "[Remote: Locust] Running load test..."
    ssh -i train.pem ubuntu@$LOCUST_IP << EOF
      cd $REMOTE_PATH_LOCUST

      echo "[Locust] Activating Python environment..."
      source .venv/bin/activate

      bash load_test.sh hpa/hpa_${ROUND}
EOF

    # --- Step 5: Local - Cleanup Minikube ---
    echo "[Local] Deleting Minikube cluster..."
    minikube delete
  done
done

echo "All rounds completed for all models."
