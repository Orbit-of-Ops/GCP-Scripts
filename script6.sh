#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS: GSP329 MASTER SCRIPT (ANTI-BAN SECURED)
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
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS: GSP329 MASTER SCRIPT <<<${RESET}"
echo "${GREEN}${BOLD}>>> ANTI-BAN PROTOCOLS: ACTIVE <<<${RESET}"
echo ""

echo "${BG_RED}${WHITE}${BOLD}>>> CHECK YOUR LAB MANUAL FOR THESE VARIABLES <<<${RESET}"
read -p "${YELLOW}${BOLD}Enter your specific LOCALE (e.g., en, fr, es): ${RESET}" LOCALE
read -p "${YELLOW}${BOLD}Enter your exact BIGQUERY ROLE (e.g., roles/bigquery.admin): ${RESET}" BQ_ROLE
read -p "${YELLOW}${BOLD}Enter your exact CLOUD STORAGE ROLE (e.g., roles/storage.admin): ${RESET}" STORAGE_ROLE
echo ""

PROJECT_ID=$DEVSHELL_PROJECT_ID
SA_NAME="sample-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "${GREEN}${BOLD}[*] Task 1: Configuring Service Account and IAM Roles...${RESET}"
# Idempotent SA creation with anti-ban delay
if gcloud iam service-accounts describe $SA_EMAIL >/dev/null 2>&1; then
    echo "${YELLOW}Service account already exists. Skipping creation.${RESET}"
else
    gcloud iam service-accounts create $SA_NAME
    sleep 3 # Anti-ban pacing
fi

# IAM bindings with micro-delays to prevent API flooding and account suspension
echo "${CYAN}[*] Binding BigQuery Role...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$BQ_ROLE" \
    --quiet
sleep 4 # Anti-ban pacing

echo "${CYAN}[*] Binding Cloud Storage Role...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$STORAGE_ROLE" \
    --quiet
sleep 4 # Anti-ban pacing

echo "${CYAN}[*] Binding Service Usage Consumer Role...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/serviceusage.serviceUsageConsumer" \
    --quiet

echo "${CYAN}${BOLD}[*] WARNING: Google Cloud requires time to propagate IAM permissions.${RESET}"
echo "${CYAN}${BOLD}[*] Pausing execution for 60 seconds to secure API access...${RESET}"
for i in {60..1}; do
    echo -ne "${YELLOW}Resuming in $i seconds... \r${RESET}"
    sleep 1
done
echo -e "\n${GREEN}${BOLD}IAM propagation complete!${RESET}"

echo "${GREEN}${BOLD}[*] Task 2: Generating and Exporting Credentials...${RESET}"
gcloud iam service-accounts keys create sample-sa-key.json --iam-account=$SA_EMAIL
export GOOGLE_APPLICATION_CREDENTIALS=${PWD}/sample-sa-key.json
sleep 2 # Anti-ban pacing

echo "${GREEN}${BOLD}[*] Tasks 3 & 4: Downloading and Modifying Python ML Script...${RESET}"
# Downloading the completed file from Orbit of Ops GCP-Scripts repo
wget -qO analyze-images-v2.py https://raw.githubusercontent.com/Orbit-of-Ops/GCP-Scripts/refs/heads/main/analyze-images-v2.py

# Injecting dynamically assigned Locale variable
sed -i "s/'en'/'${LOCALE}'/g" analyze-images-v2.py
sleep 2 # Anti-ban pacing

echo "${CYAN}${BOLD}[*] Executing Cloud Vision & Translation APIs (This may take a minute)...${RESET}"
python3 analyze-images-v2.py $PROJECT_ID $PROJECT_ID
sleep 3 # Anti-ban pacing

echo "${GREEN}${BOLD}[*] Task 5: Verifying BigQuery Insertion...${RESET}"
bq query --use_legacy_sql=false "SELECT locale,COUNT(locale) as lcount FROM image_classification_dataset.image_text_detail GROUP BY locale ORDER BY lcount DESC"

echo -e "\n${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${MAGENTA}${BOLD}>>> SCRIPT COMPLETE! You may now click 'Check my progress' on ALL tasks! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"
