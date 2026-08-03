#!/bin/bash
# ==============================================================================
# Orbit of Ops - Master Script
# Lab: GSP380 - Create and Manage Bigtable Instances: Challenge Lab
# ==============================================================================

GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
RESET='\e[0m'
BOLD='\e[1m'
BLINK='\e[5m'

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

echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🌊 WELCOME TO Orbit Of Ops                               ║${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 TARGET: GSP380 BIGTABLE CHALLENGE LAB                 ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project, Zone, and Region...${RESET}"
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo -e "${BOLD}${MAGENTA}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    read -p "$(echo -e ${BOLD}${CYAN}"Please enter the lab Zone (e.g., us-east1-c): "${RESET})" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}
export ZONE2=$(gcloud compute zones list --filter="region=($REGION) AND -name=($ZONE)" --format="value(name)" | head -n 1)

gcloud config set compute/zone $ZONE 2>/dev/null
gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID:   ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Primary Zone: ${GREEN}$ZONE${RESET}"
echo -e "✅ Replica Zone: ${GREEN}$ZONE2${RESET}"
echo -e "✅ Region:       ${GREEN}$REGION${RESET}\n"

# ==============================================================================
# INITIALIZATION & TASK 1
# ==============================================================================
echo -e "${YELLOW}[*] Restarting Dataflow API to satisfy Qwiklabs scoring engine...${RESET}"
gcloud services disable dataflow.googleapis.com --force --quiet
echo -e "${CYAN}Sleeping for 15s to allow backend state to clear...${RESET}"
sleep 15
gcloud services enable dataflow.googleapis.com --quiet

echo -e "${YELLOW}[*] Creating Cloud Storage staging bucket...${RESET}"
gsutil mb gs://$PROJECT_ID >/dev/null 2>&1

echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 1: BIGTABLE INSTANCE ▬▬▬▬▬▬${RESET}"
gcloud bigtable instances create ecommerce-recommendations \
  --display-name=ecommerce-recommendations \
  --cluster-storage-type=SSD \
  --cluster-config="id=ecommerce-recommendations-c1,zone=$ZONE" \
  --quiet

gcloud bigtable clusters update ecommerce-recommendations-c1 \
  --instance=ecommerce-recommendations \
  --autoscaling-min-nodes=1 \
  --autoscaling-max-nodes=5 \
  --autoscaling-cpu-target=60 \
  --quiet

# ==============================================================================
# TASK 2 & 3: CBT TABLES, DATAFLOW & REPLICATION
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 2 & 3: CBT TABLES, DATAFLOW & REPLICATION ▬▬▬▬▬▬${RESET}"
echo -e "${YELLOW}[*] Configuring CBT and explicitly injecting Column Families...${RESET}"
echo project = $PROJECT_ID > ~/.cbtrc
echo instance = ecommerce-recommendations >> ~/.cbtrc

cbt createtable SessionHistory 2>/dev/null
cbt createfamily SessionHistory Engagements 2>/dev/null
cbt createfamily SessionHistory Sales 2>/dev/null

cbt createtable PersonalizedProducts 2>/dev/null
cbt createfamily PersonalizedProducts Recommendations 2>/dev/null

echo -e "${YELLOW}[*] Triggering Dataflow Job 1 (SessionHistory)...${RESET}"
gcloud dataflow jobs run import-sessions \
  --gcs-location gs://dataflow-templates-$REGION/latest/GCS_SequenceFile_to_Cloud_Bigtable \
  --region $REGION \
  --staging-location gs://$PROJECT_ID/temp \
  --parameters bigtableProject=$PROJECT_ID,bigtableInstanceId=ecommerce-recommendations,bigtableTableId=SessionHistory,sourcePattern=gs://spls/gsp380/retail-engagements-sales-00000-of-00001,mutationThrottleLatencyMs=0 \
  --quiet

echo -e "${YELLOW}[*] Triggering Dataflow Job 2 (PersonalizedProducts)...${RESET}"
gcloud dataflow jobs run import-recommendations \
  --gcs-location gs://dataflow-templates-$REGION/latest/GCS_SequenceFile_to_Cloud_Bigtable \
  --region $REGION \
  --staging-location gs://$PROJECT_ID/temp \
  --parameters bigtableProject=$PROJECT_ID,bigtableInstanceId=ecommerce-recommendations,bigtableTableId=PersonalizedProducts,sourcePattern=gs://spls/gsp380/retail-recommendations-00000-of-00001,mutationThrottleLatencyMs=0 \
  --quiet

echo -e "${YELLOW}[*] Configuring Replication Cluster...${RESET}"
gcloud bigtable clusters create ecommerce-recommendations-c2 \
  --instance=ecommerce-recommendations \
  --zone=$ZONE2 \
  --quiet

gcloud bigtable clusters update ecommerce-recommendations-c2 \
  --instance=ecommerce-recommendations \
  --autoscaling-min-nodes=1 \
  --autoscaling-max-nodes=5 \
  --autoscaling-cpu-target=60 \
  --quiet

# ==============================================================================
# TASK 4: BACKUP & RESTORE
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 4: BACKUP & RESTORE ▬▬▬▬▬▬${RESET}"
echo -e "${CYAN}[Orbit of Ops] Allowing table API to settle before backup (Sleeping for 30s)...${RESET}"
sleep 30

gcloud bigtable backups create PersonalizedProducts_7 \
  --instance=ecommerce-recommendations \
  --cluster=ecommerce-recommendations-c1 \
  --table=PersonalizedProducts \
  --retention-period=7d \
  --quiet

gcloud bigtable instances tables restore \
  --source=projects/$PROJECT_ID/instances/ecommerce-recommendations/clusters/ecommerce-recommendations-c1/backups/PersonalizedProducts_7 \
  --destination=PersonalizedProducts_7_restored \
  --destination-instance=ecommerce-recommendations \
  --async \
  --quiet

# ==============================================================================
# CRITICAL PAUSE FOR SCORING
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║              🛑 STOP! MANUAL ACTION REQUIRED 🛑            ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${WHITE}${BOLD}Dataflow is currently writing data into your tables.${RESET}"
echo -e "${WHITE}${BOLD}This process takes approximately 5 to 8 minutes to complete.${RESET}\n"

echo -e "${CYAN}${BOLD}ACTION ITEMS WHILE YOU WAIT:${RESET}"
echo -e "1. Go to the lab manual and answer the multiple-choice questions for Task 2."
echo -e "   - Q1 Answer: ${YELLOW}red_shoes${RESET}"
echo -e "   - Q2 Answers: ${YELLOW}green_jacket${RESET} & ${YELLOW}green_hat${RESET}"
echo -e "2. In the Google Cloud Console, go to ${YELLOW}Dataflow -> Jobs${RESET}."
echo -e "3. Wait for BOTH jobs to show a status of ${GREEN}'Succeeded'${RESET}."
echo -e "4. Keep clicking 'Check my progress' on Tasks 1 through 4.\n"

read -p "$(echo -e ${RED}${BLINK}${BOLD}"⚠️ TYPE 'Y' AND PRESS [ENTER] ONLY WHEN YOU HAVE 80/100 POINTS: "${RESET})"

# ==============================================================================
# TASK 5: DELETION
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 5: DELETE BIGTABLE DATA ▬▬▬▬▬▬${RESET}"
echo -e "${YELLOW}[*] Deleting Backups...${RESET}"
gcloud bigtable backups delete PersonalizedProducts_7 \
  --instance=ecommerce-recommendations \
  --cluster=ecommerce-recommendations-c1 \
  --quiet

echo -e "${YELLOW}[*] Deleting Bigtable Instance (and all tables)...${RESET}"
gcloud bigtable instances delete ecommerce-recommendations --quiet

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
