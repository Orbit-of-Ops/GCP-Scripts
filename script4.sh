#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS: GSP375 PARTNER SCRIPT (USER 1)
# ==============================================================================
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
MAGENTA=$(tput setaf 5)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

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
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS: GSP375 PARTNER SCRIPT (USER 1) <<<${RESET}"
echo ""

read -p "${YELLOW}${BOLD}Enter PARTNER PROJECT ID: ${RESET}" PARTNER_PROJECT
read -p "${YELLOW}${BOLD}Enter PARTNER Authorized View Name (Task 1): ${RESET}" PARTNER_VIEW
read -p "${YELLOW}${BOLD}Enter CUSTOMER USERNAME (Email 2): ${RESET}" CUSTOMER_USER
echo ""

echo "${GREEN}[*] Creating Partner Authorized View...${RESET}"
bq query --use_legacy_sql=false --project_id=$PARTNER_PROJECT \
"CREATE OR REPLACE VIEW \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` AS SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`;"

echo "${GREEN}[*] Authorizing View in Dataset (Idempotent)...${RESET}"
bq show --format=prettyjson ${PARTNER_PROJECT}:demo_dataset > dataset.json
jq --arg prj "$PARTNER_PROJECT" --arg ds "demo_dataset" --arg vw "$PARTNER_VIEW" \
'.access |= (map(select(.view.tableId != $vw)) + [{"view": {"projectId": $prj, "datasetId": $ds, "tableId": $vw}}])' dataset.json > updated_dataset.json
bq update --source updated_dataset.json ${PARTNER_PROJECT}:demo_dataset

echo "${GREEN}[*] Granting Data Viewer IAM Role...${RESET}"
bq query --use_legacy_sql=false --project_id=$PARTNER_PROJECT \
"GRANT \`roles/bigquery.dataViewer\` ON VIEW \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` TO 'user:${CUSTOMER_USER}';"

echo -e "\n${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${MAGENTA}${BOLD}>>> PARTNER SCRIPT COMPLETE! Click Check Progress for Task 1! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"
