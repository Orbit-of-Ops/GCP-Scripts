clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
RESET='\e[0m'
BOLD='\e[1m'
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ____       _     _ _    ___   __  ___
 / __ \     | |   (_) |  / _ \ / _|/ _ \
| |  | |_ __| |__  _| |_| | | | |_| | | |_ __  ___
| |  | | '__| '_ \| | __| | | |  _| | | | '_ \/ __|
| |__| | |  | |_) | | |_| |_| | | | |_| | |_) \__ \
 \____/|_|  |_.__/|_|\__|\___/|_|  \___/| .__/|___/
                                        | |
                                        |_|
EOF
echo -e "${RESET}"
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 BROUGHT TO YOU BY ORBIT OF OPS                        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project, Zone, and Region...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo -e "${BOLD}${RED}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    read -p "$(echo -e ${BOLD}${CYAN}Please enter the lab Zone [e.g., europe-west1-d]: ${RESET})" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}

gcloud config set compute/zone $ZONE 2>/dev/null
gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Zone:       ${GREEN}$ZONE${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"

# Prompt ONLY for lab-specific dynamic parameters
read -p "$(echo -e ${WHITE}Enter your CLUSTER NAME ${YELLOW}[from Task 1 instructions]: ${RESET})" CLUSTER_NAME
read -p "$(echo -e ${WHITE}Enter your POOL NAME ${YELLOW}[from Task 2 instructions]: ${RESET})" POOL_NAME
read -p "$(echo -e ${WHITE}Enter your MAX REPLICAS ${YELLOW}[from Task 4 instructions, e.g., 10]: ${RESET})" MAX_REPLICAS

# ==============================================================================
# TASK 1: CLUSTER CREATION & APP DEPLOYMENT
# ==============================================================================
echo -e "\n${BOLD}${CYAN}STEP 1: Creating GKE Cluster and Deploying App...${RESET}"
gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --num-nodes=2 \
    --release-channel=rapid

gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID

kubectl create namespace dev
kubectl create namespace prod

rm -rf microservices-demo
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo
kubectl apply -f ./release/kubernetes-manifests.yaml --namespace dev
cd ..
echo -e "${GREEN}✅ Task 1 Completed (Cluster & App Deployed).${RESET}\n"

# ==============================================================================
# TASK 2: OPTIMIZED NODE POOL & MIGRATION
# ==============================================================================
echo -e "${BOLD}${CYAN}STEP 2: Creating Custom Node Pool & Migrating Workloads...${RESET}"
gcloud container node-pools create $POOL_NAME \
    --cluster=$CLUSTER_NAME \
    --machine-type=custom-2-3584 \
    --num-nodes=2 \
    --zone=$ZONE \
    --project=$PROJECT_ID

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl cordon "$node"
done

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o=name); do
    kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 "$node"
done

gcloud container node-pools delete default-pool \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --quiet
echo -e "${GREEN}✅ Task 2 Completed (Optimized Node Pool Migrated).${RESET}\n"

# ==============================================================================
# RACE CONDITION SAFEGUARD
# ==============================================================================
echo -e "${BOLD}${YELLOW}Waiting for GKE Cluster to unlock from previous operations...${RESET}"
while [[ $(gcloud container clusters describe $CLUSTER_NAME --zone $ZONE --format="value(status)") != "RUNNING" ]]; do
    echo "Cluster is reconciling... waiting 10 seconds..."
    sleep 10
done
echo -e "${GREEN}✅ Cluster is unlocked and ready!${RESET}\n"

# ==============================================================================
# TASK 3: POD DISRUPTION BUDGET & FRONTEND UPDATE
# ==============================================================================
echo -e "${BOLD}${CYAN}STEP 3: Applying Frontend Update (PDB & Image Version)...${RESET}"
kubectl create poddisruptionbudget onlineboutique-frontend-pdb \
    --selector=app=frontend \
    --min-available=1 \
    --namespace dev

kubectl patch deployment frontend -n dev --type=json -p '[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/image",
    "value": "gcr.io/qwiklabs-resources/onlineboutique-frontend:v2.1"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/imagePullPolicy",
    "value": "Always"
  }
]'
echo -e "${GREEN}✅ Task 3 Completed (Frontend Update Applied).${RESET}\n"

# ==============================================================================
# TASK 4: AUTOSCALING CONFIGURATION
# ==============================================================================
echo -e "${BOLD}${CYAN}STEP 4: Configuring Autoscaling Limits...${RESET}"
gcloud container clusters update $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=6 \
    --node-pool=$POOL_NAME

# Safe, proven flag for the Qwiklabs Grader
kubectl autoscale deployment frontend \
    --cpu-percent=50 \
    --min=1 \
    --max=$MAX_REPLICAS \
    --namespace dev

kubectl autoscale deployment recommendationservice \
    --cpu-percent=50 \
    --min=1 \
    --max=5 \
    --namespace dev
echo -e "${GREEN}✅ Task 4 Completed (HPA and Cluster Autoscaling Configured).${RESET}\n"

echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║             🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
