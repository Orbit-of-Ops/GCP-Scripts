#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS: GSP351 FULLY AUTOMATED MASTER SCRIPT
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)
BG_RED=$(tput setab 1)

echo "${CYAN}${BOLD}"
echo "   ____       _     _ _            __   ___             "
echo "  / __ \     | |   (_) |          / _| / _ \            "
echo " | |  | |_ __| |__  _| |_   ___  | |_ | | | |_ __  ___  "
echo " | |  | | '__| '_ \| | __| / _ \ |  _|| | | | '_ \/ __| "
echo " | |__| | |  | |_) | | |_ | (_) || |  | |_| | |_) \__ \ "
echo "  \____/|_|  |_.__/|_|\__| \___/ |_|   \___/| .__/|___/ "
echo "                                            | |         "
echo "                                            |_|         "
echo "${RESET}"
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS: GSP351 MASTER SCRIPT (ZERO INPUT) <<<${RESET}"
echo ""

echo "${GREEN}${BOLD}[*] Scanning Qwiklabs environment and extracting variables dynamically...${RESET}"

# Dynamically fetch Zone and Region
ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud compute instances list --format="value(zone)" | head -n 1)
fi
REGION=${ZONE%-*}

# Dynamically fetch the Compute Instance name and its External IP
COMPUTE_INSTANCE=$(gcloud compute instances list --format="value(name)" | head -n 1)
SOURCE_IP=$(gcloud compute instances describe $COMPUTE_INSTANCE --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

# Dynamically fetch Cloud SQL Instance names for the UI instructions
ONE_TIME_SQL=$(gcloud sql instances list --format="value(name)" | grep -v "cont")
CONT_SQL=$(gcloud sql instances list --format="value(name)" | grep "cont")
PROFILE_ID="mysql-source-profile"

echo "${YELLOW}${BOLD}--- Extracted Lab Details ---${RESET}"
echo "${CYAN}Region:${RESET} ${WHITE}$REGION${RESET}"
echo "${CYAN}Compute Instance:${RESET} ${WHITE}$COMPUTE_INSTANCE${RESET}"
echo "${CYAN}Source External IP:${RESET} ${GREEN}${BOLD}$SOURCE_IP${RESET}"
echo "${CYAN}One-Time SQL Target:${RESET} ${WHITE}$ONE_TIME_SQL${RESET}"
echo "${CYAN}Continuous SQL Target:${RESET} ${WHITE}$CONT_SQL${RESET}"
echo "${YELLOW}${BOLD}-----------------------------${RESET}"
echo ""

echo "${GREEN}${BOLD}[*] Enabling Required APIs (Database Migration & Service Networking)...${RESET}"
gcloud services enable datamigration.googleapis.com servicenetworking.googleapis.com --quiet

echo "${GREEN}${BOLD}[*] Task 1: Creating Connection Profile Automatically...${RESET}"
if gcloud database-migration connection-profiles describe "$PROFILE_ID" --region="$REGION" >/dev/null 2>&1; then
  echo "${YELLOW}${BOLD}Profile '$PROFILE_ID' already exists. Skipping creation to maintain idempotency.${RESET}"
else
  # The lab standardizes the DB credentials as admin/changeme for all users
  gcloud database-migration connection-profiles create mysql "$PROFILE_ID" \
    --display-name="$PROFILE_ID" \
    --region="$REGION" \
    --host="$SOURCE_IP" \
    --port="3306" \
    --username="admin" \
    --password="changeme"
  echo "${GREEN}${BOLD}Connection Profile created successfully!${RESET}"
fi

echo -e "\n${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${MAGENTA}${BOLD}>>> TASK 1 COMPLETE! Click 'Check my progress' for Task 1! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"

# ==============================================================================
# UI INSTRUCTIONS FOR TASKS 2, 3, 4, 5
# ==============================================================================
echo -e "\n${BG_RED}${WHITE}${BOLD}>>> ACTION REQUIRED FOR TASKS 2, 3, 4 & 5 <<<${RESET}"
echo "${YELLOW}${BOLD}Follow these exact steps in the Google Cloud Console UI:${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 2: One-Time Migration${RESET}"
echo "${WHITE}1. Go to ${BOLD}Database Migration > Migration Jobs > CREATE MIGRATION JOB${RESET}${WHITE}.${RESET}"
echo "${WHITE}2. Name it: ${BOLD}one-time-migration${RESET} ${WHITE}(or check manual for specific name).${RESET}"
echo "${WHITE}3. Source: ${BOLD}MySQL${RESET}${WHITE} | Destination: ${BOLD}Cloud SQL for MySQL${RESET}${WHITE} | Job Type: ${BOLD}One-time${RESET}${WHITE}.${RESET}"
echo "${WHITE}4. Source Connection Profile: Select ${BOLD}${PROFILE_ID}${RESET}${WHITE}.${RESET}"
echo "${WHITE}5. Destination Instance: Select ${BOLD}Existing instance${RESET}${WHITE} -> choose ${BOLD}${ONE_TIME_SQL}${RESET}${WHITE}.${RESET}"
echo "${WHITE}6. Test the job, then click ${BOLD}START${RESET}${WHITE}. (Click Check Progress for Task 2)${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 3: Continuous Migration (VPC Peering)${RESET}"
echo "${WHITE}1. Create a SECOND Migration Job.${RESET}"
echo "${WHITE}2. Name it: ${BOLD}${CONT_SQL}${RESET}"
echo "${WHITE}3. Source: ${BOLD}MySQL${RESET}${WHITE} | Destination: ${BOLD}Cloud SQL for MySQL${RESET}${WHITE} | Job Type: ${BOLD}Continuous${RESET}${WHITE}.${RESET}"
echo "${WHITE}4. Source Connection Profile: Select ${BOLD}${PROFILE_ID}${RESET}${WHITE} again.${RESET}"
echo "${WHITE}5. Destination Instance: Select ${BOLD}Existing instance${RESET}${WHITE} -> choose ${BOLD}${CONT_SQL}${RESET}${WHITE}.${RESET}"
echo "${WHITE}6. Connectivity Method: Select ${BOLD}VPC Peering${RESET}${WHITE} (use the 'default' network).${RESET}"
echo "${WHITE}7. Test the job, then click ${BOLD}START${RESET}${WHITE}. WAIT for status to say 'Running' (Click Check Progress for Task 3).${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 4: Test Replication (RUN THIS IN CLOUD SHELL)${RESET}"
echo "${YELLOW}${BOLD}Once Task 3 is RUNNING, copy and paste this exact command into your Cloud Shell to update the database:${RESET}"
echo -e "${MAGENTA}${BOLD}mysql -h $SOURCE_IP -u admin -pchangeme -e \"use customers_data; update customers set gender = 'FEMALE' where addressKey = 934;\"${RESET}"
echo "${WHITE}(Click Check Progress for Task 4)${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 5: Promote Destination Database${RESET}"
echo "${WHITE}1. Go back to your Migration Jobs list in the console.${RESET}"
echo "${WHITE}2. Click your CONTINUOUS migration job (${CONT_SQL}).${RESET}"
echo "${WHITE}3. Click the ${BOLD}PROMOTE${RESET}${WHITE} button at the top and confirm.${RESET}"
echo -e "\n${GREEN}${BOLD}Click 'Check my progress' for Task 5 to secure your 100/100!${RESET}"
