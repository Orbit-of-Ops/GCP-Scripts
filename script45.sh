#!/bin/bash

clear

# ==============================================================================
# Color Variables & Orbit of Ops Branding
# ==============================================================================
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
BOLD='\e[1m'
RESET='\e[0m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ____       _     _ _            __    ___            
 / __ \     | |   (_) |          / _|  / _ \           
| |  | |_ __| |__  _| |_   ___  | |_  | | | |_ __  ___ 
| |  | | '__| '_ \| | __| / _ \ |  _| | | | | '_ \/ __|
| |__| | |  | |_) | | |_ | (_) || |   | |_| | |_) \__ \
 \____/|_|  |_.__/|_|\__| \___/ |_|    \___/| .__/|___/
                                            | |        
                                            |_|        
EOF
echo -e "${RESET}"
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (GSP319)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project Configuration...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo -e "${BOLD}${RED}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    echo -ne "${BOLD}${CYAN}Please enter the lab Zone (e.g., us-east1-c): ${RESET}"
    read ZONE
    export ZONE
fi

gcloud config set compute/zone $ZONE 2>/dev/null

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Zone:       ${GREEN}$ZONE${RESET}\n"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# USER INPUT
# ==============================================================================
echo -e "${BOLD}${YELLOW}⚠️ ATTENTION: Check your lab instructions for the following exact names: ${RESET}"

echo -ne "${BOLD}${CYAN}Enter the Cluster Name: ${RESET}"
read CLUSTER_NAME

echo -ne "${BOLD}${CYAN}Enter the Monolith Identifier: ${RESET}"
read MONOLITH_IDENTIFIER

echo -ne "${BOLD}${CYAN}Enter the Orders Identifier: ${RESET}"
read ORDERS_IDENTIFIER

echo -ne "${BOLD}${CYAN}Enter the Products Identifier: ${RESET}"
read PRODUCTS_IDENTIFIER

echo -ne "${BOLD}${CYAN}Enter the Frontend Identifier: ${RESET}"
read FRONTEND_IDENTIFIER

echo -e "\n${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Enabling required APIs and downloading source code...${RESET}"
gcloud services enable cloudbuild.googleapis.com container.googleapis.com
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh

# Ensure NVM is active before running NodeJS commands
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Building and pushing the Monolith container...${RESET}"
cd ~/monolith-to-microservices/monolith
gcloud builds submit --tag gcr.io/${PROJECT_ID}/${MONOLITH_IDENTIFIER}:1.0.0 . --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Creating GKE cluster ($CLUSTER_NAME) and deploying Monolith...${RESET}"
gcloud container clusters create $CLUSTER_NAME --num-nodes 3 --zone $ZONE --machine-type e2-medium --quiet
kubectl create deployment $MONOLITH_IDENTIFIER --image=gcr.io/${PROJECT_ID}/${MONOLITH_IDENTIFIER}:1.0.0
kubectl expose deployment $MONOLITH_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8080

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3 & 4: Building, pushing, and deploying Orders microservice...${RESET}"
cd ~/monolith-to-microservices/microservices/src/orders
gcloud builds submit --tag gcr.io/${PROJECT_ID}/${ORDERS_IDENTIFIER}:1.0.0 . --quiet
kubectl create deployment $ORDERS_IDENTIFIER --image=gcr.io/${PROJECT_ID}/${ORDERS_IDENTIFIER}:1.0.0
kubectl expose deployment $ORDERS_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8081

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3 & 4: Building, pushing, and deploying Products microservice...${RESET}"
cd ~/monolith-to-microservices/microservices/src/products
gcloud builds submit --tag gcr.io/${PROJECT_ID}/${PRODUCTS_IDENTIFIER}:1.0.0 . --quiet
kubectl create deployment $PRODUCTS_IDENTIFIER --image=gcr.io/${PROJECT_ID}/${PRODUCTS_IDENTIFIER}:1.0.0
kubectl expose deployment $PRODUCTS_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8082

echo -e "\n${BOLD}${YELLOW}⏳ Waiting for LoadBalancer External IPs to be assigned (This takes ~1-2 minutes)...${RESET}"
ORDERS_IP=""
PRODUCTS_IP=""

while [[ -z "$ORDERS_IP" || "$ORDERS_IP" == "pending" ]]; do
    ORDERS_IP=$(kubectl get svc $ORDERS_IDENTIFIER -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    sleep 5
done

while [[ -z "$PRODUCTS_IP" || "$PRODUCTS_IP" == "pending" ]]; do
    PRODUCTS_IP=$(kubectl get svc $PRODUCTS_IDENTIFIER -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    sleep 5
done

echo -e "${GREEN}✅ Orders IP found: $ORDERS_IP${RESET}"
echo -e "${GREEN}✅ Products IP found: $PRODUCTS_IP${RESET}"

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 5: Updating React .env and recompiling Frontend...${RESET}"
cd ~/monolith-to-microservices/react-app

cat > .env <<EOF
REACT_APP_ORDERS_URL=http://$ORDERS_IP/api/orders
REACT_APP_PRODUCTS_URL=http://$PRODUCTS_IP/api/products
EOF

npm run build

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 6: Building and pushing Frontend container...${RESET}"
cd ~/monolith-to-microservices/microservices/src/frontend
gcloud builds submit --tag gcr.io/${PROJECT_ID}/${FRONTEND_IDENTIFIER}:1.0.0 . --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 7: Deploying and exposing Frontend...${RESET}"
kubectl create deployment $FRONTEND_IDENTIFIER --image=gcr.io/${PROJECT_ID}/${FRONTEND_IDENTIFIER}:1.0.0
kubectl expose deployment $FRONTEND_IDENTIFIER --type=LoadBalancer --port 80 --target-port 8080

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
