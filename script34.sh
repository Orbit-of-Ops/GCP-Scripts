clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
RESET='\e[0m'
BOLD='\e[1m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
RED='\e[1;31m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ____       _     _ _    ___   __  ___
 / __ \     | |   (_) |  / _ \ / _|/ _ \
| |  | |_ __| |__  _| |_| | | | |_| | | |_ __  ___
| |  | | '__| '_ \| | __| | | |  _| | | | '_ \/ __|
| |__| | |  | |_) | | |_| |_| | | | |_| | |_) \__ \
 \____/|_|  |_.__/|_|\__|\___/|_|  \___/| .__/|___/
                                        | |
                                        |_|
EOF
echo -e "${RESET}"
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 BROUGHT TO YOU BY ORBIT OF OPS                        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES
# ==============================================================================
echo -e "${BOLD}${YELLOW}Auto-fetching Project details...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi
gcloud config set project $PROJECT_ID --quiet

export DETECTED_REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items.google-compute-default-region)" 2>/dev/null)

if [[ -z "$DETECTED_REGION" ]]; then
    read -p "$(echo -e ${BOLD}${CYAN}Please enter the lab Region [e.g., us-east4]: ${RESET})" REGION
else
    read -p "$(echo -e ${BOLD}${CYAN}Detected Region is ${GREEN}$DETECTED_REGION${CYAN}. Press Enter to confirm or type a new one: ${RESET})" INPUT_REGION
    REGION=${INPUT_REGION:-$DETECTED_REGION}
fi
export REGION

gcloud config set run/region $REGION 2>/dev/null
gcloud config set run/platform managed 2>/dev/null

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"

# Prompt ONLY for lab-specific dynamic parameters from the Qwiklabs panel
echo -e "${YELLOW}${BOLD}Please copy the exact names from your Qwiklabs instructions panel:${RESET}"
read -p "$(echo -e ${WHITE}Task 1: Enter Public Billing Service name: ${RESET})" PUBLIC_BILLING_SERVICE
read -p "$(echo -e ${WHITE}Task 2: Enter Frontend Staging Service name: ${RESET})" FRONTEND_STAGING_SERVICE
read -p "$(echo -e ${WHITE}Task 3: Enter Private Billing Service name: ${RESET})" PRIVATE_BILLING_SERVICE
read -p "$(echo -e ${WHITE}Task 4: Enter Billing Service Account name: ${RESET})" BILLING_SERVICE_ACCOUNT
read -p "$(echo -e ${WHITE}Task 5: Enter Billing Prod Service name: ${RESET})" BILLING_PROD_SERVICE
read -p "$(echo -e ${WHITE}Task 6: Enter Frontend Service Account name: ${RESET})" FRONTEND_SERVICE_ACCOUNT
read -p "$(echo -e ${WHITE}Task 7: Enter Frontend Production Service name: ${RESET})" FRONTEND_PRODUCTION_SERVICE

echo -e "\n${BOLD}${BLUE}Cloning Source Code Repository...${RESET}"
rm -rf pet-theory
git clone https://github.com/rosera/pet-theory.git

# ==============================================================================
# TASK 1: DEPLOY PUBLIC BILLING SERVICE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 1] Deploying Public Billing Service...${RESET}"
cd ~/pet-theory/lab07/unit-api-billing
gcloud builds submit --tag gcr.io/$PROJECT_ID/billing-staging-api:0.1 .
gcloud run deploy $PUBLIC_BILLING_SERVICE \
    --image gcr.io/$PROJECT_ID/billing-staging-api:0.1 \
    --allow-unauthenticated \
    --quiet
echo -e "${GREEN}✅ Task 1 Completed.${RESET}"

# ==============================================================================
# TASK 2: DEPLOY FRONTEND SERVICE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 2] Deploying Staging Frontend Service...${RESET}"
cd ~/pet-theory/lab07/staging-frontend-billing
gcloud builds submit --tag gcr.io/$PROJECT_ID/frontend-staging:0.1 .
gcloud run deploy $FRONTEND_STAGING_SERVICE \
    --image gcr.io/$PROJECT_ID/frontend-staging:0.1 \
    --allow-unauthenticated \
    --quiet
echo -e "${GREEN}✅ Task 2 Completed.${RESET}"

# ==============================================================================
# TASK 3: DEPLOY PRIVATE BILLING SERVICE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 3] Deleting old service & Deploying Private Billing Service...${RESET}"
gcloud run services delete $PUBLIC_BILLING_SERVICE --quiet
cd ~/pet-theory/lab07/staging-api-billing
gcloud builds submit --tag gcr.io/$PROJECT_ID/billing-staging-api:0.2 .
gcloud run deploy $PRIVATE_BILLING_SERVICE \
    --image gcr.io/$PROJECT_ID/billing-staging-api:0.2 \
    --no-allow-unauthenticated \
    --quiet
echo -e "${GREEN}✅ Task 3 Completed.${RESET}"

# ==============================================================================
# TASK 4: CREATE BILLING SERVICE ACCOUNT
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 4] Creating Billing Service Account...${RESET}"
gcloud iam service-accounts create $BILLING_SERVICE_ACCOUNT \
    --display-name "Billing Service Cloud Run"
echo -e "${YELLOW}Waiting 10 seconds for IAM propagation...${RESET}"
sleep 10
echo -e "${GREEN}✅ Task 4 Completed.${RESET}"

# ==============================================================================
# TASK 5: DEPLOY PRODUCTION BILLING SERVICE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 5] Deploying Production Billing Service...${RESET}"
cd ~/pet-theory/lab07/prod-api-billing
gcloud builds submit --tag gcr.io/$PROJECT_ID/billing-prod-api:0.1 .
gcloud run deploy $BILLING_PROD_SERVICE \
    --image gcr.io/$PROJECT_ID/billing-prod-api:0.1 \
    --no-allow-unauthenticated \
    --service-account $BILLING_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com \
    --quiet
echo -e "${GREEN}✅ Task 5 Completed.${RESET}"

# ==============================================================================
# TASK 6: CREATE FRONTEND SERVICE ACCOUNT & BIND ROLE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 6] Creating Frontend Service Account & Binding IAM Roles...${RESET}"
gcloud iam service-accounts create $FRONTEND_SERVICE_ACCOUNT \
    --display-name "Billing Service Cloud Run Invoker"

echo -e "${YELLOW}Waiting 10 seconds for IAM propagation...${RESET}"
sleep 10

gcloud run services add-iam-policy-binding $BILLING_PROD_SERVICE \
    --region $REGION \
    --member="serviceAccount:$FRONTEND_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/run.invoker" \
    --quiet
echo -e "${GREEN}✅ Task 6 Completed.${RESET}"

# ==============================================================================
# TASK 7: DEPLOY PRODUCTION FRONTEND SERVICE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 7] Deploying Production Frontend Service...${RESET}"
cd ~/pet-theory/lab07/prod-frontend-billing
gcloud builds submit --tag gcr.io/$PROJECT_ID/frontend-prod:0.1 .
gcloud run deploy $FRONTEND_PRODUCTION_SERVICE \
    --image gcr.io/$PROJECT_ID/frontend-prod:0.1 \
    --allow-unauthenticated \
    --service-account $FRONTEND_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com \
    --quiet
echo -e "${GREEN}✅ Task 7 Completed.${RESET}\n"

echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║             🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
