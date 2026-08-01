#!/bin/bash

clear

# ==============================================================================
# Color Variables & Orbit of Ops Branding
# ==============================================================================
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
BOLD='\e[1m'
RESET='\e[0m'

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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (GSP341)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project, Zone, and Region...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)' 2>/dev/null)

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo -e "${BOLD}${RED}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    read -p "$(echo -e ${BOLD}${CYAN}Please enter the lab Zone \(e.g., us-east1-c\): ${RESET})" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}

gcloud config set compute/zone $ZONE 2>/dev/null
gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Zone:       ${GREEN}$ZONE${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Task 1: Creating BigQuery dataset 'ecommerce'...${RESET}"
bq --location=US mk -d ecommerce

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Training initial logistic regression model (This may take 2-3 minutes)...${RESET}"
bq query --use_legacy_sql=false '
CREATE OR REPLACE MODEL `ecommerce.customer_classification_model`
OPTIONS
(
  model_type="logistic_reg",
  labels = ["will_buy_on_return_visit"]
) AS

SELECT
  * EXCEPT(fullVisitorId)
FROM
  (SELECT
    fullVisitorId,
    IFNULL(totals.bounces, 0) AS bounces,
    IFNULL(totals.timeOnSite, 0) AS time_on_site
  FROM
    `data-to-insights.ecommerce.web_analytics`
  WHERE
    totals.newVisits = 1
    AND date BETWEEN "20160801" AND "20170430") 
JOIN
  (SELECT
    fullvisitorid,
    IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM
    `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid)
USING (fullVisitorId)'

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Evaluating initial model performance...${RESET}"
bq query --use_legacy_sql=false "
SELECT
  roc_auc,
  CASE
    WHEN roc_auc > 0.9 THEN 'good'
    WHEN roc_auc > 0.8 THEN 'fair'
    WHEN roc_auc > 0.7 THEN 'decent'
    WHEN roc_auc > 0.6 THEN 'not great'
    ELSE 'poor'
  END AS model_quality
FROM
  ML.EVALUATE(MODEL ecommerce.customer_classification_model, (
    SELECT
      * EXCEPT(fullVisitorId)
    FROM (
      SELECT
        fullVisitorId,
        IFNULL(totals.bounces, 0) AS bounces,
        IFNULL(totals.timeOnSite, 0) AS time_on_site
      FROM \`data-to-insights.ecommerce.web_analytics\`
      WHERE totals.newVisits = 1
        AND date BETWEEN '20170501' AND '20170630'
    )
    JOIN (
      SELECT
        fullVisitorId,
        IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
      FROM \`data-to-insights.ecommerce.web_analytics\`
      GROUP BY fullVisitorId
    )
    USING (fullVisitorId)
  ));
"

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Training improved customer classification model (This may take 3-4 minutes)...${RESET}"
bq query --use_legacy_sql=false '
CREATE OR REPLACE MODEL `ecommerce.improved_customer_classification_model`
OPTIONS (
  model_type="logistic_reg",
  input_label_cols = ["will_buy_on_return_visit"]
) AS

WITH all_visitor_stats AS (
  SELECT
    fullvisitorid,
    IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)

SELECT * EXCEPT(unique_session_id) FROM (
  SELECT
    CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
    will_buy_on_return_visit,
    MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
    IFNULL(totals.bounces, 0) AS bounces,
    IFNULL(totals.timeOnSite, 0) AS time_on_site,
    IFNULL(totals.pageviews, 0) AS pageviews,
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    device.deviceCategory,
    IFNULL(geoNetwork.country, "") AS country
  FROM `data-to-insights.ecommerce.web_analytics`,
    UNNEST(hits) AS h
  JOIN all_visitor_stats USING(fullvisitorid)
  WHERE totals.newVisits = 1
    AND date BETWEEN "20160801" AND "20170430"
  GROUP BY
    unique_session_id,
    will_buy_on_return_visit,
    bounces,
    time_on_site,
    totals.pageviews,
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    device.deviceCategory,
    country
)'

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Evaluating improved model performance...${RESET}"
bq query --use_legacy_sql=false "
SELECT
  roc_auc,
  CASE
    WHEN roc_auc > 0.9 THEN 'good'
    WHEN roc_auc > 0.8 THEN 'fair'
    WHEN roc_auc > 0.7 THEN 'decent'
    WHEN roc_auc > 0.6 THEN 'not great'
    ELSE 'poor'
  END AS model_quality
FROM
  ML.EVALUATE(MODEL \`ecommerce.improved_customer_classification_model\`, (
    WITH all_visitor_stats AS (
      SELECT
        fullvisitorid,
        IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
      FROM \`data-to-insights.ecommerce.web_analytics\`
      GROUP BY fullvisitorid
    )
    SELECT
      CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
      will_buy_on_return_visit,
      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
      IFNULL(totals.bounces, 0) AS bounces,
      IFNULL(totals.timeOnSite, 0) AS time_on_site,
      IFNULL(totals.pageviews, 0) AS pageviews,
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      device.deviceCategory,
      IFNULL(geoNetwork.country, '') AS country
    FROM \`data-to-insights.ecommerce.web_analytics\`,
      UNNEST(hits) AS h
    JOIN all_visitor_stats USING(fullvisitorid)
    WHERE totals.newVisits = 1
      AND date BETWEEN '20170501' AND '20170630'
    GROUP BY
      unique_session_id,
      will_buy_on_return_visit,
      bounces,
      time_on_site,
      pageviews,
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      device.deviceCategory,
      country
  ));
"

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 4: Training finalized model with selected features (This may take 3-4 minutes)...${RESET}"
bq query --use_legacy_sql=false '
CREATE OR REPLACE MODEL `ecommerce.finalized_classification_model`
OPTIONS (
  model_type="logistic_reg",
  labels = ["will_buy_on_return_visit"]
) AS

WITH all_visitor_stats AS (
  SELECT
    fullvisitorid,
    IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM `data-to-insights.ecommerce.web_analytics`
  GROUP BY fullvisitorid
)

SELECT * EXCEPT(unique_session_id) FROM (
  SELECT
    CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
    will_buy_on_return_visit,
    MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
    IFNULL(totals.bounces, 0) AS bounces,
    IFNULL(totals.timeOnSite, 0) AS time_on_site,
    IFNULL(totals.pageviews, 0) AS pageviews,
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    device.deviceCategory,
    IFNULL(geoNetwork.country, "") AS country
  FROM `data-to-insights.ecommerce.web_analytics`,
    UNNEST(hits) AS h
  JOIN all_visitor_stats USING(fullvisitorid)
  WHERE totals.newVisits = 1
    AND date BETWEEN "20160801" AND "20170430"
  GROUP BY
    unique_session_id,
    will_buy_on_return_visit,
    bounces,
    time_on_site,
    totals.pageviews,
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    device.deviceCategory,
    country
)'

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 4: Predicting with finalized model...${RESET}"
bq query --use_legacy_sql=false '
SELECT
  *
FROM
  ML.PREDICT(MODEL `ecommerce.finalized_classification_model`, (
    WITH all_visitor_stats AS (
      SELECT
        fullvisitorid,
        IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
      FROM `data-to-insights.ecommerce.web_analytics`
      GROUP BY fullvisitorid
    )
    SELECT
      CONCAT(fullvisitorid, "-", CAST(visitId AS STRING)) AS unique_session_id,
      will_buy_on_return_visit,
      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
      IFNULL(totals.bounces, 0) AS bounces,
      IFNULL(totals.timeOnSite, 0) AS time_on_site,
      totals.pageviews,
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      device.deviceCategory,
      IFNULL(geoNetwork.country, "") AS country
    FROM `data-to-insights.ecommerce.web_analytics`,
      UNNEST(hits) AS h
    JOIN all_visitor_stats USING(fullvisitorid)
    WHERE totals.newVisits = 1
      AND date BETWEEN "20170701" AND "20170801"
    GROUP BY
      unique_session_id,
      will_buy_on_return_visit,
      bounces,
      time_on_site,
      totals.pageviews,
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      device.deviceCategory,
      country
  ))
ORDER BY
  predicted_will_buy_on_return_visit DESC'

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
