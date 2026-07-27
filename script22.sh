#!/bin/bash
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
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
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 TARGET: Get Started with Eventarc: Challenge Lab      ║${RESET}"
echo -e "${BLUE}${BOLD}║   🌐 BROUGHT TO YOU BY ORBIT OF OPS                        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ----------------------------------------------------------------------
# Auto-Fetching Variables
# ----------------------------------------------------------------------
export PROJECT_ID=$DEVSHELL_PROJECT_ID
if [ -z "$PROJECT_ID" ]; then
  export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

export REGION=$(gcloud config get-value compute/region 2>/dev/null)
export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)

if [ -z "$REGION" ] || [ "$REGION" == "(unset)" ]; then
    if [ -n "$ZONE" ] && [ "$ZONE" != "(unset)" ]; then
        export REGION=${ZONE%-*}
    else
        echo -e "${YELLOW}${BOLD}Region not found automatically.${RESET}"
        read -p "Please paste the REGION from your lab instructions and press Enter: " REGION
    fi
fi

export LOCATION=$REGION

echo -e "${CYAN}${BOLD}Project: $PROJECT_ID${RESET}"
echo -e "${CYAN}${BOLD}Region: $REGION${RESET}\n"

gcloud config set compute/region $REGION
gcloud config set run/region $REGION
gcloud config set eventarc/location $REGION

# ----------------------------------------------------------------------
# Task Execution
# ----------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}Enabling necessary APIs...${RESET}"
gcloud services enable run.googleapis.com \
    eventarc.googleapis.com \
    pubsub.googleapis.com \
    logging.googleapis.com \
    cloudbuild.googleapis.com

echo -e "\n${YELLOW}${BOLD}Task 1: Creating Pub/Sub topic and subscription...${RESET}"
gcloud pubsub topics create ${PROJECT_ID}-topic
gcloud pubsub subscriptions create --topic ${PROJECT_ID}-topic ${PROJECT_ID}-topic-sub

echo -e "\n${YELLOW}${BOLD}Task 2: Deploying Cloud Run sink (pubsub-events)...${RESET}"
gcloud run deploy pubsub-events \
  --image=gcr.io/cloudrun/hello \
  --platform=managed \
  --region=${LOCATION} \
  --allow-unauthenticated

echo -e "\n${YELLOW}${BOLD}Task 3: Creating and testing Pub/Sub event trigger using Eventarc...${RESET}"

# Robust retry loop to handle Eventarc service agent propagation delay
while ! gcloud eventarc triggers create pubsub-events-trigger \
  --location=${LOCATION} \
  --destination-run-service=pubsub-events \
  --destination-run-region=${LOCATION} \
  --transport-topic=${PROJECT_ID}-topic \
  --event-filters="type=google.cloud.pubsub.topic.v1.messagePublished"; do
    echo -e "${CYAN}Waiting for Eventarc service agent to be ready. Retrying in 15 seconds...${RESET}"
    sleep 15
done

echo -e "\n${YELLOW}${BOLD}Publishing test message to verify the trigger...${RESET}"
gcloud pubsub topics publish ${PROJECT_ID}-topic \
  --message="Test message from Orbit of Ops automation"

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
