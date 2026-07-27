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
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC129 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

# ==============================================================================
# User Variable Prompt
# ==============================================================================
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo -e "${YELLOW}${BOLD}[*] Project ID: ${PROJECT_ID}${RESET}\n"

echo -e "${CYAN}${BOLD}⚠️  ATTENTION: USER 2 CREDENTIALS REQUIRED ⚠️${RESET}"
read -p "Enter User 2 Email (e.g., student-xx-xxxx@qwiklabs.net): " USER_2
echo ""

# ==============================================================================
# Execution Steps
# ==============================================================================
echo -e "${CYAN}${BOLD}[Orbit of Ops] Step 1: Creating BigQuery Dataset & Connection...${RESET}"
bq mk --location=US online_shop 2>/dev/null || true
bq mk --connection --location=US --project_id=$PROJECT_ID --connection_type=CLOUD_RESOURCE user_data_connection 2>/dev/null || true

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Step 2: Granting BigLake Service Account Permissions...${RESET}"
export SERVICE_ACCOUNT=$(bq show --format=json --connection $PROJECT_ID.US.user_data_connection | jq -r '.cloudResource.serviceAccountId')
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT --role=roles/storage.objectViewer --quiet

echo -e "${MAGENTA}${BOLD}[Orbit of Ops] Step 3: Creating BigLake Table Definition...${RESET}"
bq mkdef --autodetect --connection_id=$PROJECT_ID.US.user_data_connection --source_format=CSV "gs://$PROJECT_ID-bucket/user-online-sessions.csv" > /tmp/tabledef.json
bq mk --external_table_definition=/tmp/tabledef.json --project_id=$PROJECT_ID online_shop.user_online_sessions 2>/dev/null || true

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Step 4: Removing User 2 IAM Policy Binding...${RESET}"
if [[ -n "$USER_2" ]]; then
    gcloud projects remove-iam-policy-binding ${PROJECT_ID} --member="user:$USER_2" --role="roles/storage.objectViewer" --quiet
else
    echo -e "${RED}${BOLD}[!] Skipping IAM cleanup - No username provided.${RESET}"
fi

# ==============================================================================
# Cleanup & Completion
# ==============================================================================
rm /tmp/tabledef.json arc129.sh 2>/dev/null

echo -e "\n${GREEN}${BOLD}🎉 SCRIPT COMPLETE! ${YELLOW}Please follow the UI steps in the Horizon App guide to finish Task 2!${RESET}"
