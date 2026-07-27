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
echo -e "${BLUE}${BOLD}[Orbit of Ops] Step 1: Fetching Taxonomy Name, ID, & Policy Tags...${RESET}"
export TAXONOMY_NAME=$(gcloud data-catalog taxonomies list --location=us --project=$PROJECT_ID --format="value(displayName)" --limit=1)
export TAXONOMY_ID=$(gcloud data-catalog taxonomies list --location=us --format="value(name)" --filter="displayName=$TAXONOMY_NAME" | awk -F'/' '{print $6}')
export POLICY_TAG=$(gcloud data-catalog taxonomies policy-tags list --location=us --taxonomy=$TAXONOMY_ID --format="value(name)" --limit=1)

echo -e "${CYAN}${BOLD}[Orbit of Ops] Step 2: Creating BigQuery Dataset & Connection...${RESET}"
bq mk --location=US online_shop 2>/dev/null || true
bq mk --connection --location=US --project_id=$PROJECT_ID --connection_type=CLOUD_RESOURCE user_data_connection 2>/dev/null || true

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Step 3: Granting BigLake Service Account Permissions...${RESET}"
export SERVICE_ACCOUNT=$(bq show --format=json --connection $PROJECT_ID.US.user_data_connection | jq -r '.cloudResource.serviceAccountId')
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$SERVICE_ACCOUNT --role=roles/storage.objectViewer --quiet

echo -e "${MAGENTA}${BOLD}[Orbit of Ops] Step 4: Creating BigLake Table Definition...${RESET}"
bq mkdef --autodetect --connection_id=$PROJECT_ID.US.user_data_connection --source_format=CSV "gs://$PROJECT_ID-bucket/user-online-sessions.csv" > /tmp/tabledef.json
bq mk --external_table_definition=/tmp/tabledef.json --project_id=$PROJECT_ID online_shop.user_online_sessions 2>/dev/null || true

echo -e "${BLUE}${BOLD}[Orbit of Ops] Step 5: Updating BigQuery Schema with Policy Tags...${RESET}"
cat > schema.json << EOM
[
  {"mode": "NULLABLE", "name": "ad_event_id", "type": "INTEGER"},
  {"mode": "NULLABLE", "name": "user_id", "type": "INTEGER"},
  {"mode": "NULLABLE", "name": "uri", "type": "STRING"},
  {"mode": "NULLABLE", "name": "traffic_source", "type": "STRING"},
  {"mode": "NULLABLE", "name": "zip", "policyTags": {"names": ["$POLICY_TAG"]}, "type": "STRING"},
  {"mode": "NULLABLE", "name": "event_type", "type": "STRING"},
  {"mode": "NULLABLE", "name": "state", "type": "STRING"},
  {"mode": "NULLABLE", "name": "country", "type": "STRING"},
  {"mode": "NULLABLE", "name": "city", "type": "STRING"},
  {"mode": "NULLABLE", "name": "latitude", "policyTags": {"names": ["$POLICY_TAG"]}, "type": "FLOAT"},
  {"mode": "NULLABLE", "name": "created_at", "type": "TIMESTAMP"},
  {"mode": "NULLABLE", "name": "ip_address", "policyTags": {"names": ["$POLICY_TAG"]}, "type": "STRING"},
  {"mode": "NULLABLE", "name": "session_id", "type": "STRING"},
  {"mode": "NULLABLE", "name": "longitude", "policyTags": {"names": ["$POLICY_TAG"]}, "type": "FLOAT"},
  {"mode": "NULLABLE", "name": "id", "type": "INTEGER"}
]
EOM

bq update --schema schema.json $PROJECT_ID:online_shop.user_online_sessions

echo -e "${CYAN}${BOLD}[Orbit of Ops] Step 6: Testing Secure Query Execution...${RESET}"
bq query --use_legacy_sql=false --format=csv "SELECT * EXCEPT(zip, latitude, ip_address, longitude) FROM \`${PROJECT_ID}.online_shop.user_online_sessions\`"

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Step 7: Removing User 2 IAM Policy Binding...${RESET}"
if [[ -n "$USER_2" ]]; then
    gcloud projects remove-iam-policy-binding ${PROJECT_ID} --member="user:$USER_2" --role="roles/storage.objectViewer" --quiet
else
    echo -e "${RED}${BOLD}[!] Skipping IAM cleanup - No username provided.${RESET}"
fi

# ==============================================================================
# Cleanup & Completion
# ==============================================================================
rm /tmp/tabledef.json schema.json arc129.sh 2>/dev/null

echo -e "\n${GREEN}${BOLD}🎉 Congratulations For Completing The Lab !!!${RESET}"
echo -e "${GREEN}${BOLD}>>> MISSION COMPLETE! Check all progress bars in Qwiklabs. <<<${RESET}"
