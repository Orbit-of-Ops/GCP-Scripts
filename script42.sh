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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (GSP327)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project Configuration...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi
echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}\n"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# USER INPUT
# ==============================================================================
echo -e "${BOLD}${YELLOW}⚠️ ATTENTION: Check your lab instructions for the following values: ${RESET}"

echo -ne "${BOLD}${CYAN}Enter the Target Table Name (e.g., taxi_training_data): ${RESET}"
read TABLE_NAME
export TABLE_NAME

echo -ne "${BOLD}${CYAN}Enter the Target Column Name (e.g., fare_amount_123): ${RESET}"
read FARE_AMOUNT_NAME
export FARE_AMOUNT_NAME

echo -ne "${BOLD}${CYAN}Enter the trip_distance threshold (e.g., 0): ${RESET}"
read TRIP_DISTANCE_NO
export TRIP_DISTANCE_NO

echo -ne "${BOLD}${CYAN}Enter the fare_amount minimum threshold (e.g., 2.5): ${RESET}"
read FARE_AMOUNT
export FARE_AMOUNT

echo -ne "${BOLD}${CYAN}Enter the passenger_count threshold (e.g., 0): ${RESET}"
read PASSENGER_COUNT
export PASSENGER_COUNT

echo -ne "${BOLD}${CYAN}Enter the ML Model Name (e.g., fare_model): ${RESET}"
read MODEL_NAME
export MODEL_NAME

echo -e "\n${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Task 1: Cleaning data and creating $TABLE_NAME table...${RESET}"
bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE
  taxirides.$TABLE_NAME AS
SELECT
  (tolls_amount + fare_amount) AS $FARE_AMOUNT_NAME,
  pickup_datetime,
  pickup_longitude AS pickuplon,
  pickup_latitude AS pickuplat,
  dropoff_longitude AS dropofflon,
  dropoff_latitude AS dropofflat,
  passenger_count AS passengers,
FROM
  taxirides.historical_taxi_rides_raw
WHERE
  RAND() < 0.001
  AND trip_distance > $TRIP_DISTANCE_NO
  AND fare_amount >= $FARE_AMOUNT
  AND pickup_longitude > -78
  AND pickup_longitude < -70
  AND dropoff_longitude > -78
  AND dropoff_longitude < -70
  AND pickup_latitude > 37
  AND pickup_latitude < 45
  AND dropoff_latitude > 37
  AND dropoff_latitude < 45
  AND passenger_count > $PASSENGER_COUNT
"

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Creating and training ML model ($MODEL_NAME)...${RESET}"
echo -e "${BOLD}${YELLOW}⏳ This process takes roughly 3-5 minutes. Please wait...${RESET}"
bq query --use_legacy_sql=false "
CREATE OR REPLACE MODEL taxirides.$MODEL_NAME
TRANSFORM(
  * EXCEPT(pickup_datetime),
  ST_Distance(ST_GeogPoint(pickuplon, pickuplat), ST_GeogPoint(dropofflon, dropofflat)) AS euclidean,
  CAST(EXTRACT(DAYOFWEEK FROM pickup_datetime) AS STRING) AS dayofweek,
  CAST(EXTRACT(HOUR FROM pickup_datetime) AS STRING) AS hourofday
)
OPTIONS(input_label_cols=['$FARE_AMOUNT_NAME'], model_type='linear_reg')
AS
SELECT * FROM taxirides.$TABLE_NAME
"

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Generating batch predictions for 2015 data...${RESET}"
bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE taxirides.2015_fare_amount_predictions AS
SELECT * FROM ML.PREDICT(MODEL taxirides.$MODEL_NAME, (
  SELECT * FROM taxirides.report_prediction_data
))
"

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
