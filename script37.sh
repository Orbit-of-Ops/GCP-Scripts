clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
RESET='\e[0m'
BOLD='\e[1m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
RED='\e[1;31m'

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
# PRE-FLIGHT CHECKS & VARIABLES
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project and Zone...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    read -p "$(echo -e ${BOLD}${CYAN}Please enter the lab Zone [e.g., us-east1-b]: ${RESET})" ZONE
fi

gcloud config set compute/zone $ZONE 2>/dev/null
echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Zone:       ${GREEN}$ZONE${RESET}\n"

# Prompt for lab-specific dynamic parameters
echo -e "${YELLOW}${BOLD}Please enter the exact names from your Qwiklabs instructions panel:${RESET}"
read -p "$(echo -e ${WHITE}Task 1: Enter Custom Security Role Name ${YELLOW}[e.g., orca_storage_role]${WHITE}: ${RESET})" CUSTOM_ROLE
read -p "$(echo -e ${WHITE}Task 2: Enter Service Account Name ${YELLOW}[e.g., orca-cluster-sa]${WHITE}: ${RESET})" S_A
read -p "$(echo -e ${WHITE}Task 4: Enter Cluster Name ${YELLOW}[e.g., orca-cluster]${WHITE}: ${RESET})" CLUSTER_NAME

export SA_EMAIL="$S_A@$PROJECT_ID.iam.gserviceaccount.com"

# ==============================================================================
# TASK 1: CREATE A CUSTOM SECURITY ROLE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 1] Creating Custom Security Role: $CUSTOM_ROLE...${RESET}"
cat > role-definition.yaml <<EOF_END
title: "$CUSTOM_ROLE"
description: "Permissions for Orca Storage"
stage: "ALPHA"
includedPermissions:
- storage.buckets.get
- storage.objects.get
- storage.objects.list
- storage.objects.update
- storage.objects.create
EOF_END

gcloud iam roles create $CUSTOM_ROLE --project $PROJECT_ID --file role-definition.yaml --quiet
echo -e "${GREEN}✅ Task 1 Completed.${RESET}"

# ==============================================================================
# TASK 2: CREATE A SERVICE ACCOUNT
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 2] Creating Service Account: $S_A...${RESET}"
gcloud iam service-accounts create $S_A --display-name "Orca Private Cluster Service Account"
echo -e "${GREEN}✅ Task 2 Completed.${RESET}"

# ==============================================================================
# TASK 3: BIND IAM SECURITY ROLES
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 3] Binding Security Roles to the Service Account...${RESET}"
echo -e "${YELLOW}Waiting 5 seconds for IAM to propagate before binding...${RESET}"
sleep 5

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/monitoring.viewer" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/monitoring.metricWriter" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/logging.logWriter" --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="projects/$PROJECT_ID/roles/$CUSTOM_ROLE" --quiet

echo -e "${GREEN}✅ Task 3 Completed.${RESET}"

# ==============================================================================
# TASK 4: CREATE KUBERNETES ENGINE PRIVATE CLUSTER
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 4] Creating Private GKE Cluster (This will take 5-8 minutes)...${RESET}"

# Dynamically fetch the internal IP of the Jumphost
export JUMPHOST_IP=$(gcloud compute instances describe orca-jumphost \
    --zone=$ZONE \
    --format='get(networkInterfaces[0].networkIP)')
echo -e "${YELLOW}Detected Jumphost IP for Master Authorized Network: $JUMPHOST_IP${RESET}"

gcloud container clusters create $CLUSTER_NAME \
    --zone=$ZONE \
    --num-nodes=1 \
    --master-ipv4-cidr=172.16.0.64/28 \
    --network=orca-build-vpc \
    --subnetwork=orca-build-subnet \
    --enable-master-authorized-networks \
    --master-authorized-networks=$JUMPHOST_IP/32 \
    --enable-ip-alias \
    --enable-private-nodes \
    --enable-private-endpoint \
    --service-account=$SA_EMAIL \
    --quiet
echo -e "${GREEN}✅ Task 4 Completed.${RESET}"

# ==============================================================================
# TASK 5: DEPLOY APPLICATION VIA JUMPHOST
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 5] Connecting to Jumphost and Deploying Test Application...${RESET}"

# Sending a robust SSH command batch to the Jumphost to perform the deployment
gcloud compute ssh --zone="$ZONE" "orca-jumphost" --project="$PROJECT_ID" --quiet --command="
    sudo apt-get update
    sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin -y
    export USE_GKE_GCLOUD_AUTH_PLUGIN=True
    gcloud container clusters get-credentials $CLUSTER_NAME --internal-ip --zone=$ZONE --project=$PROJECT_ID
    kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
    kubectl expose deployment hello-server --name orca-hello-service --type LoadBalancer --port 80 --target-port 8080
"
echo -e "${GREEN}✅ Task 5 Completed.${RESET}\n"

echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║             🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"

# Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos
