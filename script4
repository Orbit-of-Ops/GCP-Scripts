#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS AUTOMATION: GSP375 SHARE DATA CHALLENGE LAB
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
echo "${MAGENTA}${BOLD}>>> INITIATING ORBIT OF OPS BI-DIRECTIONAL DATA AUTOMATION <<<${RESET}"
echo ""
echo "${WHITE}${BOLD}Gather the randomized variables from your lab instructions!${RESET}"
echo "You will need IDs and Usernames for BOTH the Partner and Customer projects."
echo ""

# --- VARIABLE COLLECTION ---
echo "${YELLOW}${BOLD}--- PARTNER DETAILS (Project 1) ---${RESET}"
read -p "Enter PARTNER PROJECT ID: " PARTNER_PROJECT
read -p "Enter PARTNER USERNAME (Email 1): " PARTNER_USER
read -p "Enter PARTNER Authorized View Name (Task 1): " PARTNER_VIEW

echo -e "\n${YELLOW}${BOLD}--- CUSTOMER DETAILS (Project 2) ---${RESET}"
read -p "Enter CUSTOMER PROJECT ID: " CUSTOMER_PROJECT
read -p "Enter CUSTOMER USERNAME (Email 2): " CUSTOMER_USER
read -p "Enter CUSTOMER Authorized Table Name (Task 3): " CUSTOMER_VIEW

echo -e "\n${CYAN}${BOLD}[*] ALL VARIABLES SECURED. EXECUTING CROSS-PROJECT PIPELINE...${RESET}\n"

# ==============================================================================
# TASK 1: PARTNER AUTHORIZED VIEW & IAM
# ==============================================================================
echo "${GREEN}[*] Task 1: Creating Partner Authorized View & Granting Access...${RESET}"
bq query --use_legacy_sql=false --project_id=$PARTNER_PROJECT \
"CREATE OR REPLACE VIEW \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` AS SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`;"

# Authorize the view inside the dataset
bq show --format=prettyjson ${PARTNER_PROJECT}:demo_dataset > dataset.json
jq --arg prj "$PARTNER_PROJECT" --arg ds "demo_dataset" --arg vw "$PARTNER_VIEW" \
'.access += [{"view": {"projectId": $prj, "datasetId": $ds, "tableId": $vw}}]' dataset.json > updated_dataset.json
bq update --source updated_dataset.json ${PARTNER_PROJECT}:demo_dataset --quiet

# Grant Data Viewer Role using DCL
bq query --use_legacy_sql=false --project_id=$PARTNER_PROJECT \
"GRANT \`roles/bigquery.dataViewer\` ON TABLE \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` TO 'user:${CUSTOMER_USER}';"

# ==============================================================================
# TASK 2: UPDATE CUSTOMER DATA TABLE
# ==============================================================================
echo -e "\n${GREEN}[*] Task 2: Executing Cross-Project Update Query...${RESET}"
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"UPDATE \`${CUSTOMER_PROJECT}.customer_dataset.customer_info\` cust SET cust.county=vw.county FROM \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` vw WHERE vw.zip_code=cust.postal_code;"

# ==============================================================================
# TASK 3: CUSTOMER AUTHORIZED VIEW & IAM
# ==============================================================================
echo -e "\n${GREEN}[*] Task 3: Creating Customer Authorized View & Granting Access...${RESET}"
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"CREATE OR REPLACE VIEW \`${CUSTOMER_PROJECT}.customer_dataset.${CUSTOMER_VIEW}\` AS SELECT county, COUNT(1) AS Count FROM \`${CUSTOMER_PROJECT}.customer_dataset.customer_info\` cust GROUP BY county HAVING county is not null;"

# Authorize the view inside the dataset
bq show --format=prettyjson ${CUSTOMER_PROJECT}:customer_dataset > cust_dataset.json
jq --arg prj "$CUSTOMER_PROJECT" --arg ds "customer_dataset" --arg vw "$CUSTOMER_VIEW" \
'.access += [{"view": {"projectId": $prj, "datasetId": $ds, "tableId": $vw}}]' cust_dataset.json > updated_cust_dataset.json
bq update --source updated_cust_dataset.json ${CUSTOMER_PROJECT}:customer_dataset --quiet

# Grant Data Viewer Role using DCL
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"GRANT \`roles/bigquery.dataViewer\` ON TABLE \`${CUSTOMER_PROJECT}.customer_dataset.${CUSTOMER_VIEW}\` TO 'user:${PARTNER_USER}';"

# ==============================================================================
# TASK 4: BACKEND API TRIGGER (PRE-WARM DATA STUDIO)
# ==============================================================================
echo -e "\n${GREEN}[*] Pre-warming BigQuery API for Task 4 validation...${RESET}"
bq query --use_legacy_sql=false --project_id=$PARTNER_PROJECT "SELECT * FROM \`${CUSTOMER_PROJECT}.customer_dataset.${CUSTOMER_VIEW}\` LIMIT 5"

# ==============================================================================
# FINALE: MANUAL GUI INSTRUCTIONS
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS PIPELINE COMPLETE! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${WHITE}${BOLD}Tasks 1, 2, and 3 are 100% finished. Click 'Check my progress' for them!${RESET}"
echo -e "\n${BG_RED}${WHITE}${BOLD}>>> ACTION REQUIRED FOR TASK 4 <<<${RESET}"
echo "${YELLOW}${BOLD}Task 4 requires manual UI clicks to generate the visualization asset:${RESET}"
echo "1. Go to Looker Studio (Data Studio) and create a Blank Report."
echo "2. Connect BigQuery and authorize it."
echo "3. Go to My Projects -> ${CUSTOMER_PROJECT} -> Select '${CUSTOMER_VIEW}' and add it."
echo "4. Name the report: ${WHITE}Data Sharing Partner Vizualization${YELLOW}"
echo "5. Insert a Vertical Bar Chart."
echo "6. Dimension = ${WHITE}county${YELLOW} | Breakdown & Metric = ${WHITE}Count${RESET}"
echo -e "\n${GREEN}${BOLD}After doing this, click 'Check my progress' for Task 4 to get 100/100!${RESET}"
