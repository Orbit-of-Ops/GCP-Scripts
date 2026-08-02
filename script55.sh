#!/bin/bash
clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
YELLOW='\e[1;33m'
GREEN='\e[1;32m'
RED='\e[1;31m'
MAGENTA='\e[1;35m'
RESET='\e[0m'
BOLD='\e[1m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ____        _     _ _             __    ___            
 / __ \      | |   (_) |           / _|  / _ \           
| |  | |_ __| |__  _| |_   ___  | |_  | | | |_ __  ___ 
| |  | | '__| '_ \| | __| / _ \ |  _| | | | | '_ \/ __|
| |__| | |  | |_) | | |_ | (_) || |   | |_| | |_) \__ \
 \____/|_|  |_.__/|_|\__| \___/ |_|    \___/| .__/|___/
                                            | |        
                                            |_|        
EOF
echo -e "${RESET}"
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 BROUGHT TO YOU BY ORBIT OF OPS — MASTER SCRIPT        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# PRE-FLIGHT CHECKS & AUTO-FETCH
# ==============================================================================
echo -e "${YELLOW}${BOLD}[Orbit of Ops] Auto-fetching Project and Region...${RESET}"
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -n "$ZONE" ]]; then
    export REGION=${ZONE%-*}
else
    echo -e "${RED}${BOLD}⚠️ Could not auto-detect region.${RESET}"
    read -p "Enter the lab REGION (e.g., us-west4): " REGION
    export REGION
fi

gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"

# LAB VARIABLES PROMPT
# ==============================================================================
echo -e "${YELLOW}${BOLD}Please enter the variables shown on your lab panel:${RESET}"
read -p "BigQuery DATASET name: " DATASET
read -p "BigQuery TABLE name: " TABLE
read -p "Pub/Sub TOPIC name: " TOPIC
read -p "Dataflow JOB name: " JOB

# TASK 0: ENABLE APIS
# ==============================================================================
echo -e "\n${CYAN}0️⃣ Enabling Dataflow & Compute APIs...${RESET}"
gcloud services enable dataflow.googleapis.com compute.googleapis.com
echo -e "${YELLOW}Waiting 20 seconds for API propagation...${RESET}"
sleep 20

# TASK 1: CREATE STORAGE BUCKET
# ==============================================================================
echo -e "\n${CYAN}1️⃣ Task 1 — Creating Cloud Storage Bucket...${RESET}"
gcloud storage buckets create gs://$PROJECT_ID --location=$REGION

# TASK 2: CREATE BIGQUERY DATASET & TABLE
# ==============================================================================
echo -e "\n${CYAN}2️⃣ Task 2 — Creating BigQuery Dataset & Table...${RESET}"
bq mk --dataset --location=US $PROJECT_ID:$DATASET
bq mk --table $PROJECT_ID:$DATASET.$TABLE data:STRING

# TASK 3: CREATE PUB/SUB TOPIC & SUBSCRIPTION
# ==============================================================================
echo -e "\n${CYAN}3️⃣ Task 3 — Creating Pub/Sub Topic & Default Subscription...${RESET}"
gcloud pubsub topics create $TOPIC
gcloud pubsub subscriptions create ${TOPIC}-sub --topic=$TOPIC

# TASK 4: LAUNCH DATAFLOW STREAMING JOB
# ==============================================================================
echo -e "\n${CYAN}4️⃣ Task 4 — Launching Dataflow Pipeline...${RESET}"
gcloud dataflow jobs run $JOB \
  --gcs-location gs://dataflow-templates-$REGION/latest/PubSub_to_BigQuery \
  --region $REGION \
  --project $PROJECT_ID \
  --staging-location gs://$PROJECT_ID/temp \
  --num-workers 1 \
  --max-workers 2 \
  --parameters inputTopic=projects/$PROJECT_ID/topics/$TOPIC,outputTableSpec=$PROJECT_ID:$DATASET.$TABLE

# TASK 5: MONITOR JOB & PUBLISH TEST MESSAGE
# ==============================================================================
echo -e "\n${CYAN}5️⃣ Task 5 — Monitoring Job State & Validating Data...${RESET}"
while true; do
    STATUS=$(gcloud dataflow jobs list --region=$REGION --format="value(name,state)" 2>/dev/null | grep -E "^$JOB" | awk '{print $2}')
    
    if [[ "$STATUS" == "Running" ]]; then
        echo -e "${GREEN}${BOLD}✅ Dataflow Job is RUNNING!${RESET}"
        
        echo -e "${YELLOW}Waiting 20 seconds for pipeline stabilization...${RESET}"
        sleep 20
        
        echo -e "${CYAN}Publishing test message to topic...${RESET}"
        gcloud pubsub topics publish $TOPIC --message='{"data": "73.4 F"}'
        
        echo -e "${YELLOW}Waiting 15 seconds before querying BigQuery...${RESET}"
        sleep 15
        
        echo -e "${CYAN}Querying BigQuery table...${RESET}"
        bq query --nouse_legacy_sql "SELECT * FROM \`$PROJECT_ID.$DATASET.$TABLE\`"
        break
    elif [[ "$STATUS" == "Failed" || "$STATUS" == "Cancelled" ]]; then
        echo -e "${RED}${BOLD}❌ Dataflow job FAILED. Please check Qwiklabs quotas or region logs.${RESET}"
        break
    else
        echo -e "${YELLOW}Dataflow job provisioning (Status: ${STATUS:-Pending}). Checking in 30 seconds...${RESET}"
        sleep 30
    fi
done

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
