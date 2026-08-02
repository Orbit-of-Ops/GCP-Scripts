clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
YELLOW='\e[1;33m'
GREEN='\e[1;32m'
MAGENTA='\e[1;35m'
RED='\e[1;31m'
RESET='\e[0m'
BOLD='\e[1m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
  ____        _     _ _             __    ___            
 / __ \      | |   (_) |           / _|  / _ \           
| |  | |_ __| |__  _| |_   ___  | |_  | | | |_ __  ___ 
| |  | | '__| '_ \| | __| / _ \ |  _| | | | | '_ \/ __|
| |__| | |  | |_) | | |_ | (_) || |   | |_| | |_) \__ \
 \____/|_|  |_.__/|_|\__| \___/ |_|    \___/| .__/|___/
                                            | |        
                                            |_|        
EOF
echo -e "${RESET}"
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 BROUGHT TO YOU BY ORBIT OF OPS — MASTER SCRIPT        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# PRE-FLIGHT CHECKS & VARIABLES
# ==============================================================================
echo -e "${YELLOW}${BOLD}[Orbit of Ops] Auto-fetching Project, Region, and Project Number...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)' 2>/dev/null)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -n "$ZONE" ]]; then
    export REGION=${ZONE%-*}
else
    echo -e "${RED}${BOLD}⚠️ Could not auto-detect region.${RESET}"
    read -p "Enter the lab REGION (e.g., us-east4): " REGION
    export REGION
fi

gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID:     ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Project Number: ${GREEN}$PROJECT_NUMBER${RESET}"
echo -e "✅ Region:         ${GREEN}$REGION${RESET}\n"

# TASK 0: PRE-REQUISITES & IAM PATCHES
# ==============================================================================
echo -e "${CYAN}0️⃣ Enabling APIs and applying Qwiklabs IAM patches...${RESET}"
gcloud services enable apigateway.googleapis.com cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com
sleep 15

# IAM Patch for Qwiklabs Artifact Registry Code 13 Error
SERVICE_ACCOUNT=$(gsutil kms serviceaccount -p $PROJECT_NUMBER 2>/dev/null)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SERVICE_ACCOUNT \
  --role=roles/artifactregistry.reader \
  --quiet >/dev/null 2>&1

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --role=roles/artifactregistry.reader \
  --quiet >/dev/null 2>&1

# TASK 1: CREATE CLOUD RUN FUNCTION (v1)
# ==============================================================================
echo -e "\n${CYAN}1️⃣ Task 1 — Deploying initial Cloud Run function (gcfunction)...${RESET}"
mkdir -p gcfunction_app
cd gcfunction_app

cat > index.js <<EOF
const functions = require('@google-cloud/functions-framework');
exports.helloHttp = functions.http('helloHttp', (req, res) => {
  res.status(200).send("Hello World!");
});
EOF

cat > package.json <<EOF
{
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF

gcloud functions deploy gcfunction \
  --region=$REGION \
  --runtime=nodejs22 \
  --trigger-http \
  --gen2 \
  --allow-unauthenticated \
  --entry-point=helloHttp \
  --source=. \
  --quiet

export FUNCTION_URI=$(gcloud functions describe gcfunction --region=$REGION --gen2 --format="value(serviceConfig.uri)")
echo -e "${GREEN}✅ Function deployed successfully at: $FUNCTION_URI${RESET}"

# TASK 2: CREATE API GATEWAY
# ==============================================================================
echo -e "\n${CYAN}2️⃣ Task 2 — Creating API Gateway (This takes ~5 minutes, please wait)...${RESET}"
cd ..
cat > openapispec.yaml <<EOF
swagger: '2.0'
info:
  title: gcfunction API
  description: Sample API on API Gateway with a Google Cloud Run functions backend
  version: 1.0.0
schemes:
  - https
produces:
  - application/json
x-google-backend:
  address: ${FUNCTION_URI}
paths:
  /gcfunction:
    get:
      summary: gcfunction
      operationId: gcfunction
      responses:
       '200':
          description: A successful response
          schema:
            type: string
EOF

echo -e "${YELLOW}Creating API (gcfunction-api)...${RESET}"
gcloud api-gateway apis create gcfunction-api --project=$PROJECT_ID --quiet 2>/dev/null || true

echo -e "${YELLOW}Creating API Config...${RESET}"
gcloud api-gateway api-configs create gcfunction-api \
  --api=gcfunction-api \
  --openapi-spec=openapispec.yaml \
  --project=$PROJECT_ID \
  --backend-auth-service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
  --quiet 2>/dev/null || true

echo -e "${YELLOW}Deploying Gateway...${RESET}"
gcloud api-gateway gateways create gcfunction-api \
  --api=gcfunction-api \
  --api-config=gcfunction-api \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet 2>/dev/null || true

# TASK 3: CREATE PUB/SUB & REDEPLOY FUNCTION
# ==============================================================================
echo -e "\n${CYAN}3️⃣ Task 3 — Creating Pub/Sub Topic and Updating Function...${RESET}"
gcloud pubsub topics create demo-topic 2>/dev/null || true
gcloud pubsub subscriptions create demo-topic-sub --topic=demo-topic 2>/dev/null || true

cd gcfunction_app
cat > index.js <<EOF
/**
 * Responds to any HTTP request.
 *
 * @param {!express:Request} req HTTP request context.
 * @param {!express:Response} res HTTP response context.
 */
const {PubSub} = require('@google-cloud/pubsub');
const pubsub = new PubSub();
const topic = pubsub.topic('demo-topic');
const functions = require('@google-cloud/functions-framework');

exports.helloHttp = functions.http('helloHttp', (req, res) => {
  // Send a message to the topic
  topic.publishMessage({data: Buffer.from('Hello from Cloud Run functions!')});
  res.status(200).send("Message sent to Topic demo-topic!");
});
EOF

cat > package.json <<EOF
{
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0",
    "@google-cloud/pubsub": "^3.4.1"
  }
}
EOF

echo -e "${YELLOW}Redeploying updated function...${RESET}"
gcloud functions deploy gcfunction \
  --region=$REGION \
  --runtime=nodejs22 \
  --trigger-http \
  --gen2 \
  --allow-unauthenticated \
  --entry-point=helloHttp \
  --source=. \
  --quiet

# FINAL INVOCATION
# ==============================================================================
echo -e "\n${CYAN}4️⃣ Triggering the Gateway to test Pub/Sub integration...${RESET}"
export GATEWAY_URL=$(gcloud api-gateway gateways describe gcfunction-api --location=$REGION --project=$PROJECT_ID --format="value(defaultHostname)")
echo -e "${YELLOW}Sending test request to https://${GATEWAY_URL}/gcfunction ...${RESET}"
curl -s "https://${GATEWAY_URL}/gcfunction"
echo -e "\n"

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
