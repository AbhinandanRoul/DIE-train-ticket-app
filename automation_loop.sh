#!/bin/bash

# --- Configuration ---
STGCN_IP="192.168.1.76"
JUMP_HOST_IP="192.168.1.18"
LOCUST_IP="192.168.1.146"
REMOTE_PATH_STGCN="/home/ubuntu/Carbon-Aware-AutoScaler/DeepScaler"
REMOTE_PATH_LOCUST="~/evaluation"
SSH_KEY_PATH="~/Carbon-Aware-AutoScaler/DeepScaler/train.pem"
MODEL_NAME="AdapGLD"
MODEL_ID="AdapGLD_fresh"

START_ROUND=0
MAX_ROUND=10  # Set the last round number here

SAVE_DIR="./saved_images"

for (( ROUND=$START_ROUND; ROUND<=MAX_ROUND; ROUND++ ))
do
  echo "Starting round $ROUND..."
  MODEL_FILE="$REMOTE_PATH_STGCN/model/${MODEL_ID}/${MODEL_ID}/${MODEL_ID}.pkl"

  #exit
  # --- Step 1: Local - Start Minikube and deploy Istio ---
  echo "[Local] Starting Minikube..."
  # minikube start --cpus 15 --memory 50000 --driver=docker
  minikube start --cpus 15 --memory 50000


  echo "[Local] Set environment to use Minikube Docker daemon"
  # eval $(minikube docker-env)

  echo "[Local] Load locally saved docker images into Minikube Docker daemon"
  # Loop through the .tar files and load them into Minikube's Docker daemon
  #for image_tar in "$SAVE_DIR"/*.tar; do
  #  if [ -f "$image_tar" ]; then
  #    echo "Loading image $image_tar into Docker..."
  #    docker load -i "$image_tar" || { echo "Failed to load $image_tar"; continue; }
  #  else
  #    echo "No .tar files found in $saved_images_dir."
  #    break
  #  fi
  #done


  echo "[Local] Deploying Istio..."
  bash deploy_istio.sh

  # --- Step 2: STGCN - Set up port forwarding, run training and background prediction ---
  echo "[Remote: STGCN] Starting model training and prediction..."

  ssh -i train.pem ubuntu@$STGCN_IP << EOF
    cd $REMOTE_PATH_STGCN

    echo "[STGCN] Setting up port forwarding via jump host..."
    ssh -f -N -L 8443:192.168.49.2:8443 ubuntu@$JUMP_HOST_IP -i $SSH_KEY_PATH
    ssh -f -N -L 9090:localhost:9090 ubuntu@$JUMP_HOST_IP -i $SSH_KEY_PATH
    ssh -f -N -L 9091:localhost:9091 ubuntu@$JUMP_HOST_IP -i $SSH_KEY_PATH

    echo "[STGCN] Activating Python environment..."
    source ~/Carbon-Aware-AutoScaler/.myenv/bin/activate

    echo "[STGCN] Running training script..."
    # python3 main.py --model_name=$MODEL_NAME --model_save_path=$MODEL_FILE

    echo "[STGCN] Starting prediction in background..."
    nohup python3 predict_scale.py --model_name=$MODEL_NAME --model_save_path=$MODEL_FILE --round=$ROUND > predict_T.log 2>&1 &
EOF

# --- Step 3: Locust - Start load test ---
echo "[Remote: Locust] Running load test..."
  ssh -i train.pem ubuntu@$LOCUST_IP << EOF
    cd $REMOTE_PATH_LOCUST

    echo "[Locust] Activating Python environment..."
    source .venv/bin/activate

    bash load_test.sh ${MODEL_NAME}_${ROUND}
EOF

  # --- Step 4: STGCN - Kill background prediction ---
  echo "[Remote: STGCN] Killing prediction process..."
  ssh -i train.pem ubuntu@$STGCN_IP << EOF
    pkill -f "predict_scale.py"
    echo "[STGCN] Prediction process terminated."
EOF

  # --- Step 5: Local - Cleanup Minikube ---
  echo "[Local] Deleting Minikube cluster..."
  minikube delete

  echo "Round $ROUND completed."
  echo ""
done

echo "All rounds completed for ${MODEL_NAME}."
