#!/bin/bash
clear
echo "===================================================================="
echo ">>> ORBIT OF OPS: GSP375 CUSTOMER SCRIPT (USER 2) <<<"
echo "===================================================================="
read -p "Enter CUSTOMER PROJECT ID: " CUSTOMER_PROJECT
read -p "Enter CUSTOMER Authorized Table Name (Task 3): " CUSTOMER_VIEW
read -p "Enter PARTNER PROJECT ID: " PARTNER_PROJECT
read -p "Enter PARTNER Authorized View Name (Task 1): " PARTNER_VIEW
read -p "Enter PARTNER USERNAME (Email 1): " PARTNER_USER

echo "[*] Task 2: Updating Customer Data Table..."
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"UPDATE \`${CUSTOMER_PROJECT}.customer_dataset.customer_info\` cust SET cust.county=vw.county FROM \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` vw WHERE vw.zip_code=cust.postal_code;"

echo "[*] Task 3: Creating Customer Authorized View..."
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"CREATE OR REPLACE VIEW \`${CUSTOMER_PROJECT}.customer_dataset.${CUSTOMER_VIEW}\` AS SELECT county, COUNT(1) AS Count FROM \`${CUSTOMER_PROJECT}.customer_dataset.customer_info\` cust GROUP BY county HAVING county is not null;"

echo "[*] Authorizing View in Dataset..."
bq show --format=prettyjson ${CUSTOMER_PROJECT}:customer_dataset > cust_dataset.json
jq --arg prj "$CUSTOMER_PROJECT" --arg ds "customer_dataset" --arg vw "$CUSTOMER_VIEW" \
'.access += [{"view": {"projectId": $prj, "datasetId": $ds, "tableId": $vw}}]' cust_dataset.json > updated_cust_dataset.json
bq update --source updated_cust_dataset.json ${CUSTOMER_PROJECT}:customer_dataset

echo "[*] Granting Data Viewer IAM Role..."
bq query --use_legacy_sql=false --project_id=$CUSTOMER_PROJECT \
"GRANT \`roles/bigquery.dataViewer\` ON VIEW \`${CUSTOMER_PROJECT}.customer_dataset.${CUSTOMER_VIEW}\` TO 'user:${PARTNER_USER}';"

echo "===================================================================="
echo ">>> CUSTOMER SCRIPT COMPLETE! Click Check Progress for Tasks 2 & 3! <<<"
echo "===================================================================="
