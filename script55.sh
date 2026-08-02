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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (ARC106)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# USER INPUT (DYNAMIC LAB VARIABLES)
# ==============================================================================
echo -e "${BOLD}${YELLOW}⚠️ ATTENTION: Check your lab instructions for the following names: ${RESET}"

echo -ne "${BOLD}${CYAN}Enter BigQuery Dataset Name (Task 2): ${RESET}"
read DATASET_NAME

echo -ne "${BOLD}${CYAN}Enter BigQuery Table Name (Task 2): ${RESET}"
read TABLE_NAME

echo -ne "${BOLD}${CYAN}Enter Pub/Sub Topic Name (Task 3): ${RESET}"
read TOPIC_NAME

echo -ne "${BOLD}${CYAN}Enter Dataflow Job Name (Task 4): ${RESET}"
read JOB_NAME

echo -e "\n${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project and Region...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)

if [[ -z "$REGION" ]]; then
    echo -e "${BOLD}${RED}⚠️ Could not auto-detect the default region.${RESET}"
    echo -ne "${BOLD}${CYAN}Please enter the lab Region (e.g., us-central1): ${RESET}"
    read REGION
fi

gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Enabling required APIs...${RESET}"
gcloud services enable \
  bigquery.googleapis.com \
  pubsub.googleapis.com \
  dataflow.googleapis.com \
  storage-api.googleapis.com \
  --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Creating Cloud Storage bucket ($PROJECT_ID)...${RESET}"
gsutil mb -l US gs://$PROJECT_ID 2>/dev/null || true

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Creating BigQuery Dataset ($DATASET_NAME) in US...${RESET}"
bq --location=US mk --dataset $PROJECT_ID:$DATASET_NAME 2>/dev/null || true

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Creating BigQuery Table ($TABLE_NAME)...${RESET}"
bq mk --table $PROJECT_ID:$DATASET_NAME.$TABLE_NAME data:STRING 2>/dev/null || true

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Creating Pub/Sub Topic ($TOPIC_NAME) with default subscription...${RESET}"
gcloud pubsub topics create $TOPIC_NAME --quiet 2>/dev/null || true
gcloud pubsub subscriptions create ${TOPIC_NAME}-sub --topic=$TOPIC_NAME --quiet 2>/dev/null || true

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 4: Launching Dataflow Pipeline Job ($JOB_NAME)...${RESET}"
gcloud dataflow jobs run $JOB_NAME \
  --gcs-location gs://dataflow-templates-$REGION/latest/PubSub_to_BigQuery \
  --region $REGION \
  --project $PROJECT_ID \
  --staging-location gs://$PROJECT_ID/temp \
  --parameters inputTopic=projects/$PROJECT_ID/topics/$TOPIC_NAME,outputTableSpec=$PROJECT_ID:$DATASET_NAME.$TABLE_NAME

echo -e "\n${BOLD}${YELLOW}[Orbit of Ops] Task 5: Waiting for Dataflow job to enter 'Running' state to publish test message...${RESET}"
while true; do
    STATUS=$(gcloud dataflow jobs list --region=$REGION --project=$PROJECT_ID --filter="name:$JOB_NAME AND state:Running" --format="value(state)" 2>/dev/null)
    
    if [ "$STATUS" == "Running" ]; then
        echo -e "${GREEN}✅ Dataflow job is running successfully! Publishing test message...${RESET}"
        sleep 10
        
        # Publish message (Task 5)
        gcloud pubsub topics publish $TOPIC_NAME --message='{"data": "73.4 F"}'
        
        echo -e "${CYAN}Validating records in BigQuery...${RESET}"
        bq query --nouse_legacy_sql "SELECT * FROM \`$PROJECT_ID.$DATASET_NAME.$TABLE_NAME\`"
        break
    else
        echo -e "${YELLOW}⏳ Dataflow job is initializing, waiting 30 seconds...${RESET}"
        sleep 30
    fi
done

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
