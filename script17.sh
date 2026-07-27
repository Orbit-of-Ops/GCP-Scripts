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
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC123 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo -e "${YELLOW}${BOLD}[*] Project ID: ${PROJECT_ID}${RESET}\n"

# ==============================================================================
# Execution Steps (Tasks 1 & 2)
# ==============================================================================
echo -e "${BLUE}${BOLD}[Orbit of Ops] Step 1: Enabling Required APIs...${RESET}"
gcloud services enable datacatalog.googleapis.com bigqueryconnection.googleapis.com dataplex.googleapis.com --quiet

echo -e "${CYAN}${BOLD}[Orbit of Ops] Step 2: Creating BigQuery Dataset...${RESET}"
bq mk --location=US ecommerce 2>/dev/null || true

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Step 3: Creating Cloud Resource Connection...${RESET}"
bq mk --connection --location=US --project_id=$PROJECT_ID --connection_type=CLOUD_RESOURCE customer_data_connection 2>/dev/null || true

echo -e "${MAGENTA}${BOLD}[Orbit of Ops] Step 4: Granting Service Account Storage Permissions...${RESET}"
export SERVICE_ACCOUNT=$(bq show --format=json --connection $PROJECT_ID.US.customer_data_connection | jq -r '.cloudResource.serviceAccountId')
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT --role=roles/storage.objectViewer --quiet

echo -e "${BLUE}${BOLD}[Orbit of Ops] Step 5: Creating BigLake Table Definition...${RESET}"
bq mkdef --autodetect --connection_id=$PROJECT_ID.US.customer_data_connection --source_format=CSV gs://$PROJECT_ID-bucket/customer-online-sessions.csv > /tmp/tabledef.json

echo -e "${CYAN}${BOLD}[Orbit of Ops] Step 6: Creating External Lakehouse Table...${RESET}"
bq mk --external_table_definition=/tmp/tabledef.json --project_id=$PROJECT_ID ecommerce.customer_online_sessions 2>/dev/null || true

# ==============================================================================
# Cleanup & Completion
# ==============================================================================
rm /tmp/tabledef.json arc123.sh 2>/dev/null

echo -e "\n${GREEN}${BOLD}🎉 INFRASTRUCTURE COMPLETE!${RESET}"
echo -e "${YELLOW}${BOLD}>>> Please follow the Dataplex UI steps in the Horizon App guide to complete Task 3! <<<${RESET}"
