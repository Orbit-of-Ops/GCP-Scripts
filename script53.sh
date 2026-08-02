#!/bin/bash
set +H
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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (ARC112)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project and Zone...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute instances list --filter="name=lab-setup" --format="value(zone)" --limit=1 2>/dev/null)

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
echo -e "${BOLD}${YELLOW}⚠️ ATTENTION: Check your lab instructions for the following values: ${RESET}"

echo -ne "${BOLD}${CYAN}Enter the App Engine Region (from Task 3, e.g., us-central): ${RESET}"
read APP_REGION

echo -e "\n${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Task 1: Enabling the App Engine Admin API...${RESET}"
gcloud services enable appengine.googleapis.com --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Downloading the Hello World app on VM 'lab-setup'...${RESET}"
gcloud compute ssh lab-setup \
    --zone=$ZONE \
    --quiet \
    --command="git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git"

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Cloning repository locally and configuring scaling limits...${RESET}"
git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
cd python-docs-samples/appengine/standard_python3/hello_world

# Hardcode instance limits using printf to avoid copy-paste whitespace errors
printf "\nautomatic_scaling:\n  max_instances: 1\n" >> app.yaml

gcloud app create --region=$APP_REGION --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Deploying the initial application (Takes ~2 minutes)...${RESET}"
gcloud app deploy --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 4: Updating the application code with 'Hello, Cruel World!'...${RESET}"
sed -i "s/return.*/return 'Hello, Cruel World!'/g" main.py

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 4: Redeploying the updated application over the existing version...${RESET}"
# Fetch the ID of the version we just created to overwrite it and bypass the 10-instance quota
CURRENT_VERSION=$(gcloud app versions list --hide-no-traffic --format="value(version.id)" | head -n 1)

# Deploy directly over the existing version
gcloud app deploy --version=$CURRENT_VERSION --quiet

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
