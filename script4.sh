#!/bin/bash
clear
echo "===================================================================="
echo ">>> ORBIT OF OPS: GSP375 PARTNER SCRIPT (USER 1) <<<"
echo "===================================================================="
read -p "Enter PARTNER PROJECT ID: " PARTNER_PROJECT
read -p "Enter PARTNER Authorized View Name (Task 1): " PARTNER_VIEW
read -p "Enter CUSTOMER USERNAME (Email 2): " CUSTOMER_USER

echo "[*] Creating Partner Authorized View..."
bq query --use_legacy_sql=false --project_id=$PARTNER_PROJECT \
"CREATE OR REPLACE VIEW \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` AS SELECT * FROM \`bigquery-public-data.geo_us_boundaries.zip_codes\`;"

echo "[*] Authorizing View in Dataset..."
bq show --format=prettyjson ${PARTNER_PROJECT}:demo_dataset > dataset.json
jq --arg prj "$PARTNER_PROJECT" --arg ds "demo_dataset" --arg vw "$PARTNER_VIEW" \
'.access += [{"view": {"projectId": $prj, "datasetId": $ds, "tableId": $vw}}]' dataset.json > updated_dataset.json
bq update --source updated_dataset.json ${PARTNER_PROJECT}:demo_dataset

echo "[*] Granting Data Viewer IAM Role..."
bq query --use_legacy_sql=false --project_id=$PARTNER_PROJECT \
"GRANT \`roles/bigquery.dataViewer\` ON VIEW \`${PARTNER_PROJECT}.demo_dataset.${PARTNER_VIEW}\` TO 'user:${CUSTOMER_USER}';"

echo "===================================================================="
echo ">>> PARTNER SCRIPT COMPLETE! Click Check Progress for Task 1! <<<"
echo "===================================================================="
