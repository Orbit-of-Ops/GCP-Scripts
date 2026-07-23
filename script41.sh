#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS: GSP375 CUSTOMER SCRIPT (USER 2)
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
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS: GSP375 CUSTOMER SCRIPT (USER 2) <<<${RESET}"
echo ""

read -p "${YELLOW}${BOLD}Enter CUSTOMER PROJECT ID: ${RESET}" CUSTOMER_PROJECT
read -p "${YELLOW}${BOLD}Enter CUSTOMER Authorized Table Name (Task 3): ${RESET}" CUSTOMER_VIEW
read -p "${YELLOW}${BOLD}Enter PARTNER PROJECT ID: ${RESET}" PARTNER_PROJECT
read -p "${YELLOW}${BOLD}Enter PARTNER Authorized View Name (Task 1): ${RESET}" PARTNER_VIEW
read -p "${YELLOW}${BOLD}Enter PARTNER USERNAME (Email 1): ${RESET}" PARTNER_USER
echo ""

echo "${GREEN}[*] Task 2: Updating Customer Data Table...${RESET}"
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"UPDATE \`${CUSTOMER_PROJECT}.customer_dataset.customer_info\` cust SET cust.county=vw.county FROM \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` vw WHERE vw.zip_code=cust.postal_code;"

echo "${GREEN}[*] Task 3: Creating Customer Authorized View...${RESET}"
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"CREATE OR REPLACE VIEW \`${CUSTOMER_PROJECT}.customer_dataset.${CUSTOMER_VIEW}\` AS SELECT county, COUNT(1) AS Count FROM \`${CUSTOMER_PROJECT}.customer_dataset.customer_info\` cust GROUP BY county HAVING county is not null;"

echo "${GREEN}[*] Authorizing View in Dataset (Idempotent)...${RESET}"
bq show --format=prettyjson ${CUSTOMER_PROJECT}:customer_dataset > cust_dataset.json
jq --arg prj "$CUSTOMER_PROJECT" --arg ds "customer_dataset" --arg vw "$CUSTOMER_VIEW" \
'.access |= (map(select(.view.tableId != $vw)) + [{"view": {"projectId": $prj, "datasetId": $ds, "tableId": $vw}}])' cust_dataset.json > updated_cust_dataset.json
bq update --source updated_cust_dataset.json ${CUSTOMER_PROJECT}:customer_dataset

echo "${GREEN}[*] Granting Data Viewer IAM Role...${RESET}"
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"GRANT \`roles/bigquery.dataViewer\` ON VIEW \`${CUSTOMER_PROJECT}.customer_dataset.${CUSTOMER_VIEW}\` TO 'user:${PARTNER_USER}';"

echo -e "\n${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${MAGENTA}${BOLD}>>> CUSTOMER SCRIPT COMPLETE! Click Check Progress for Tasks 2 & 3! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"

# ==============================================================================
# TASK 4: MANUAL LOOKER STUDIO INSTRUCTIONS
# ==============================================================================
echo -e "\n${BG_RED}${WHITE}${BOLD}>>> ACTION REQUIRED FOR TASK 4 <<<${RESET}"
echo "${YELLOW}${BOLD}Task 4 requires manual UI clicks to generate the visualization asset:${RESET}"
echo "1. Go back to your ${WHITE}PARTNER (User 1)${YELLOW} browser window."
echo "2. Go to Looker Studio (https://lookerstudio.google.com/) and create a Blank Report."
echo "3. Connect BigQuery and authorize it."
echo "4. Go to My Projects -> ${WHITE}${CUSTOMER_PROJECT}${YELLOW} -> Select '${WHITE}${CUSTOMER_VIEW}${YELLOW}' and add it."
echo "5. Name the report: ${WHITE}Data Sharing Partner Vizualization${YELLOW}"
echo "6. Insert a Vertical Bar Chart."
echo "7. Dimension = ${WHITE}county${YELLOW} | Breakdown & Metric = ${WHITE}Count${RESET}"
echo -e "\n${GREEN}${BOLD}After doing this, click 'Check my progress' for Task 4 to get 100/100!${RESET}"
