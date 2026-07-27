#!/bin/bash
# ==============================================================================
# Color Variables & Branding
# ==============================================================================
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
RED='\e[1;31m'
RESET='\e[0m'
BOLD='\e[1m'

clear
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
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC119 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION=$(gcloud config get-value compute/region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="us-central1"
fi

echo -e "${YELLOW}${BOLD}[*] Project ID: ${PROJECT_ID} | Region: ${REGION}${RESET}\n"

# ==============================================================================
# Execution Steps
# ==============================================================================
echo -e "${BLUE}${BOLD}[Orbit of Ops] Step 1: Enabling Required APIs...${RESET}"
gcloud services enable datacatalog.googleapis.com dataplex.googleapis.com storage.googleapis.com --quiet

echo -e "${CYAN}${BOLD}[Orbit of Ops] Step 2: Creating Cloud Storage Bucket...${RESET}"
gsutil mb -l $REGION gs://$PROJECT_ID 2>/dev/null || true

# ==============================================================================
# Cleanup & Completion
# ==============================================================================
rm arc119.sh 2>/dev/null

echo -e "\n${GREEN}${BOLD}🎉 CLOUD SHELL SETUP COMPLETE!${RESET}"
echo -e "${YELLOW}${BOLD}>>> Please follow the Knowledge Catalog UI steps in the Horizon App guide to complete Tasks 2, 3, and 4! <<<${RESET}"
