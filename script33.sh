clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
RESET='\e[0m'
BOLD='\e[1m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'

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

export DEVSHELL_PROJECT_ID=$(gcloud config get-value project)
gcloud config set project $DEVSHELL_PROJECT_ID --quiet

export DETECTED_REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items.google-compute-default-region)" 2>/dev/null)

if [[ -z "$DETECTED_REGION" ]]; then
    read -p "$(echo -e ${BOLD}${CYAN}Please enter the lab Region [e.g., us-east4]: ${RESET})" REGION
else
    read -p "$(echo -e ${BOLD}${CYAN}Detected Region is ${GREEN}$DETECTED_REGION${CYAN}. Press Enter to confirm or type a new one: ${RESET})" INPUT_REGION
    REGION=${INPUT_REGION:-$DETECTED_REGION}
fi
export REGION

export DATASET_SERVICE=netflix-dataset-service
export FRONTEND_STAGING_SERVICE=frontend-staging-service
export FRONTEND_PRODUCTION_SERVICE=frontend-production-service
export AR_REPO=rest-api-repo
export FRONTEND_REPO=frontend-repo

echo -e "✅ Project ID: ${GREEN}$DEVSHELL_PROJECT_ID${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"

echo -e "${BLUE}${BOLD}Enabling required APIs...${RESET}"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com firestore.googleapis.com

# ==============================================================================
# TASK 1: CREATE FIRESTORE DATABASE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 1] Creating Firestore database (Native Mode) in $REGION...${RESET}"
gcloud firestore databases create \
  --location=$REGION \
  --type=firestore-native \
  --project=$DEVSHELL_PROJECT_ID || true
sleep 5
echo -e "${GREEN}✅ Task 1 Completed.${RESET}"

# ==============================================================================
# TASK 2: IMPORT CSV INTO FIRESTORE
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 2] Importing Netflix CSV into Firestore...${RESET}"
rm -rf ~/pet-theory
git clone https://github.com/rosera/pet-theory.git

cd ~/pet-theory/lab06/firebase-import-csv/solution || exit
npm install
node index.js netflix_titles_original.csv
echo -e "${GREEN}✅ Task 2 Completed.${RESET}"

# Configure Artifact Registry
echo -e "\n${BLUE}${BOLD}Creating Artifact Registry repositories...${RESET}"
gcloud artifacts repositories create $AR_REPO \
  --repository-format=docker \
  --location=$REGION \
  --description="REST API repo" || true

gcloud artifacts repositories create $FRONTEND_REPO \
  --repository-format=docker \
  --location=$REGION \
  --description="Frontend repo" || true

gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# ==============================================================================
# TASK 3: DEPLOY REST API v0.1
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 3] Building & Deploying REST API v0.1...${RESET}"
cd ~/pet-theory/lab06/firebase-rest-api/solution-01 || exit
npm install

gcloud builds submit --tag ${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$AR_REPO/rest-api:0.1 .

gcloud run deploy $DATASET_SERVICE \
  --image ${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$AR_REPO/rest-api:0.1 \
  --allow-unauthenticated \
  --max-instances=1 \
  --region=$REGION \
  --quiet

SERVICE_URL=$(gcloud run services describe $DATASET_SERVICE --region=$REGION --format='value(status.url)')
echo -e "${GREEN}✅ Task 3 Completed (Service URL: $SERVICE_URL)${RESET}"

# ==============================================================================
# TASK 4: DEPLOY REST API v0.2
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 4] Building & Deploying REST API v0.2...${RESET}"
cd ~/pet-theory/lab06/firebase-rest-api/solution-02 || exit
npm install

gcloud builds submit --tag ${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$AR_REPO/rest-api:0.2 .

gcloud run deploy $DATASET_SERVICE \
  --image ${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$AR_REPO/rest-api:0.2 \
  --allow-unauthenticated \
  --max-instances=1 \
  --region=$REGION \
  --quiet
echo -e "${GREEN}✅ Task 4 Completed.${RESET}"

# ==============================================================================
# TASK 5: DEPLOY STAGING FRONTEND
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 5] Building & Deploying Staging Frontend...${RESET}"
cd ~/pet-theory/lab06/firebase-frontend || exit

gcloud builds submit --tag ${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$FRONTEND_REPO/frontend-staging:0.1 .

gcloud run deploy $FRONTEND_STAGING_SERVICE \
  --image=${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$FRONTEND_REPO/frontend-staging:0.1 \
  --allow-unauthenticated \
  --max-instances=1 \
  --region=$REGION \
  --quiet

STAGING_URL=$(gcloud run services describe $FRONTEND_STAGING_SERVICE --region=$REGION --format='value(status.url)')
echo -e "${GREEN}✅ Task 5 Completed (Staging URL: $STAGING_URL)${RESET}"

# ==============================================================================
# TASK 6: DEPLOY PRODUCTION FRONTEND
# ==============================================================================
echo -e "\n${CYAN}${BOLD}[Task 6] Updating app.js & Deploying Production Frontend...${RESET}"
cd ~/pet-theory/lab06/firebase-frontend/public || exit

# Safely inject the live REST API URL into the app.js code
sed -i "s|const REST_API_SERVICE = \".*\"|const REST_API_SERVICE = \"$SERVICE_URL\"|g" app.js

cd .. || exit

gcloud builds submit --tag ${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$FRONTEND_REPO/frontend-production:0.1 .

gcloud run deploy $FRONTEND_PRODUCTION_SERVICE \
  --image=${REGION}-docker.pkg.dev/$DEVSHELL_PROJECT_ID/$FRONTEND_REPO/frontend-production:0.1 \
  --allow-unauthenticated \
  --max-instances=1 \
  --region=$REGION \
  --quiet

PROD_URL=$(gcloud run services describe $FRONTEND_PRODUCTION_SERVICE --region=$REGION --format='value(status.url)')
echo -e "${GREEN}✅ Task 6 Completed (Production URL: $PROD_URL)${RESET}\n"

echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║             🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
