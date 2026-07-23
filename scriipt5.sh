#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS: GSP351 MASTER SCRIPT
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
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS: GSP351 MASTER SCRIPT <<<${RESET}"
echo ""

read -p "${YELLOW}${BOLD}Enter your lab REGION (e.g., us-east4): ${RESET}" REGION
read -p "${YELLOW}${BOLD}Enter the Source MySQL External IP: ${RESET}" SOURCE_IP
echo ""

PROFILE_ID="mysql-source"

echo "${GREEN}${BOLD}[*] Enabling Required APIs...${RESET}"
gcloud services enable datamigration.googleapis.com servicenetworking.googleapis.com

echo "${GREEN}${BOLD}[*] Task 1: Creating Connection Profile...${RESET}"
if gcloud database-migration connection-profiles describe "$PROFILE_ID" --region="$REGION" >/dev/null 2>&1; then
  echo "${YELLOW}${BOLD}Profile '$PROFILE_ID' already exists. Skipping creation to maintain idempotency.${RESET}"
else
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
echo "${MAGENTA}${BOLD}>>> TASK 1 COMPLETE! Click Check Progress for Task 1! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"

# ==============================================================================
# UI INSTRUCTIONS FOR TASKS 2, 3, 4, 5
# ==============================================================================
echo -e "\n${BG_RED}${WHITE}${BOLD}>>> ACTION REQUIRED FOR TASKS 2, 3, 4 & 5 <<<${RESET}"
echo "${YELLOW}${BOLD}Database migrations require strict UI configurations. Follow these steps carefully:${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 2: One-Time Migration${RESET}"
echo "${WHITE}1. Go to ${BOLD}Database Migration > Migration Jobs > CREATE MIGRATION JOB${RESET}${WHITE}.${RESET}"
echo "${WHITE}2. Name: Use the one-time job name provided in your lab manual.${RESET}"
echo "${WHITE}3. Source: ${BOLD}MySQL${RESET}${WHITE} | Destination: ${BOLD}Cloud SQL for MySQL${RESET}${WHITE} | Job Type: ${BOLD}One-time${RESET}${WHITE}.${RESET}"
echo "${WHITE}4. Select the connection profile we just created (${BOLD}${PROFILE_ID}${RESET}${WHITE}).${RESET}"
echo "${WHITE}5. Destination: Select ${BOLD}Existing instance${RESET}${WHITE} and choose your one-time Cloud SQL instance.${RESET}"
echo "${WHITE}6. Test the job and click ${BOLD}START${RESET}${WHITE}.${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 3: Continuous Migration (VPC Peering)${RESET}"
echo "${WHITE}1. Create a second Migration Job.${RESET}"
echo "${WHITE}2. Name: Use the continuous job name provided in your lab manual.${RESET}"
echo "${WHITE}3. Source: ${BOLD}MySQL${RESET}${WHITE} | Destination: ${BOLD}Cloud SQL for MySQL${RESET}${WHITE} | Job Type: ${BOLD}Continuous${RESET}${WHITE}.${RESET}"
echo "${WHITE}4. Select the same connection profile (${BOLD}${PROFILE_ID}${RESET}${WHITE}).${RESET}"
echo "${WHITE}5. Destination: Select ${BOLD}Existing instance${RESET}${WHITE} and choose your continuous Cloud SQL instance.${RESET}"
echo "${WHITE}6. Connectivity: Select ${BOLD}VPC Peering${RESET}${WHITE} and configure it with the default network.${RESET}"
echo "${WHITE}7. Test the job and click ${BOLD}START${RESET}${WHITE}. Wait for the status to change to 'Running'.${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 4: Test Replication (RUN IN CLOUD SHELL)${RESET}"
echo "${YELLOW}${BOLD}WAIT until Task 3 is RUNNING! Then, copy and paste this exact command into Cloud Shell:${RESET}"
echo "${MAGENTA}${BOLD}mysql -h $SOURCE_IP -u admin -pchangeme -e \"use customers_data; update customers set gender = 'FEMALE' where addressKey = 934;\"${RESET}"

echo -e "\n${CYAN}${BOLD}TASK 5: Promote Destination Database${RESET}"
echo "${WHITE}1. In the Migration Jobs list, click your CONTINUOUS migration job.${RESET}"
echo "${WHITE}2. Click the ${BOLD}PROMOTE${RESET}${WHITE} button and confirm.${RESET}"

echo -e "\n${GREEN}${BOLD}After completing these steps, click 'Check my progress' on all remaining tasks for 100/100!${RESET}"
