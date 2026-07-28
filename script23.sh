#!/bin/bash
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
RESET='\e[0m'
BOLD='\e[1m'

clear
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
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 TARGET: Build a Smart Cloud App with Vibe Coding      ║${RESET}"
echo -e "${BLUE}${BOLD}║   🌐 BROUGHT TO YOU BY ORBIT OF OPS                        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ----------------------------------------------------------------------
# Dynamic User Input
# ----------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}⚠️ Please check your lab instructions to enter the correct names!${RESET}\n"
read -p "1. Enter your REGION (e.g., us-central1): " LOCATION
read -p "2. Enter the MCP Server Name from Task 3 (e.g., coding-zoo-mcp-server): " MCP_SERVER_NAME
read -p "3. Enter the ADK Agent Name from Task 5 (e.g., coding-zoo-tour-guide): " ADK_SERVICE_NAME

export PROJECT_ID=$(gcloud config get-value project)
export STUDENT_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

gcloud config set compute/region $LOCATION
gcloud config set run/region $LOCATION

echo -e "\n${CYAN}${BOLD}Project: $PROJECT_ID${RESET}"
echo -e "${CYAN}${BOLD}Region: $LOCATION${RESET}"
echo -e "${CYAN}${BOLD}Student Email: $STUDENT_EMAIL${RESET}\n"

# ----------------------------------------------------------------------
# Task 1 & 2: Setup and IAM
# ----------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}Enabling necessary APIs & IAM Roles...${RESET}"
gcloud services enable \
    aiplatform.googleapis.com \
    artifactregistry.googleapis.com \
    compute.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    cloudaicompanion.googleapis.com

gcloud projects add-iam-policy-binding $PROJECT_ID --member="user:$STUDENT_EMAIL" --role="roles/run.admin" --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member="user:$STUDENT_EMAIL" --role="roles/aiplatform.user" --quiet

echo -e "${YELLOW}${BOLD}Downloading and extracting boilerplate code...${RESET}"
cd ~
gcloud storage cp gs://$PROJECT_ID-labconfig-bucket/labs_code.zip .
unzip -o labs_code.zip

# ----------------------------------------------------------------------
# Task 3: Fix and Deploy MCP Server
# ----------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Fixing and testing local MCP Server (Python 3.13)...${RESET}"
cd ~/mcp-on-cloudrun
sed -i 's/# mcp = FastMCP/mcp = FastMCP/g' server.py

uv run --python 3.13 server.py &
SERVER_PID=$!
sleep 15
uv run --python 3.13 local_mcp_call.py
kill $SERVER_PID

echo -e "\n${YELLOW}${BOLD}Deploying MCP Server to Cloud Run... (This takes a few minutes)${RESET}"
gcloud run deploy $MCP_SERVER_NAME \
    --no-allow-unauthenticated \
    --region=$LOCATION \
    --source=. \
    --min=1 \
    --project=$PROJECT_ID \
    --labels=lab-dev=mcp-zoo-cloud-run-service \
    --quiet

# ----------------------------------------------------------------------
# Task 4: Configure Settings (Literal String Trap)
# ----------------------------------------------------------------------
export CLOUD_RUN_URL=$(gcloud run services describe $MCP_SERVER_NAME --region=$LOCATION --format="value(status.url)")
export ID_TOKEN=$(gcloud auth print-identity-token)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

echo -e "\n${YELLOW}${BOLD}Configuring strict Gemini CLI Settings...${RESET}"
mkdir -p ~/.gemini
cat <<EOF > ~/.gemini/settings.json
{
  "mcpServers": {
    "zoo-remote": {
      "httpUrl": "${CLOUD_RUN_URL}/mcp/",
      "headers": {
        "Authorization": "Bearer \$ID_TOKEN"
      }
    }
  },
  "selectedAuthType": "compute-default-credentials",
  "hasSeenIdeIntegrationNudge": true
}
EOF

# ----------------------------------------------------------------------
# Task 5: Configure and Deploy ADK Agent
# ----------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Updating Zoo Guide Agent configs and code...${RESET}"
cd ~/zoo_guide_agent
cat <<EOF > .env
MODEL="gemini-2.5-flash"
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
MCP_SERVER_URL="${CLOUD_RUN_URL}/mcp/"
GOOGLE_GENAI_USE_ENTERPRISE=1
GOOGLE_CLOUD_PROJECT=${PROJECT_ID}
PROJECT_NUMBER=${PROJECT_NUMBER}
GOOGLE_CLOUD_LOCATION=${LOCATION}
EOF

sed -i 's/tools=\[\]/tools=\[google_search\]/g' agent.py
sed -i 's/tools = \[\]/tools=\[google_search\]/g' agent.py
sed -i 's/tools=TODO/tools=\[google_search\]/g' agent.py
sed -i 's/tools = TODO/tools=\[google_search\]/g' agent.py

python3 -m venv .venv
source .venv/bin/activate
pip install --no-cache-dir -r requirements.txt

echo -e "\n${YELLOW}${BOLD}Deploying ADK Agent to Cloud Run (This takes 5-10 minutes)...${RESET}"
adk deploy cloud_run \
  --project=$PROJECT_ID \
  --region=$LOCATION \
  --service_name=$ADK_SERVICE_NAME \
  --with_ui \
  . \
  -- \
  --labels=lab-dev=cloud-zoo-run-adk-service \
  --quiet

echo -e "\n${YELLOW}${BOLD}Fixing 403 Forbidden: Making Cloud Run public...${RESET}"
gcloud run services add-iam-policy-binding $ADK_SERVICE_NAME \
  --region=$LOCATION \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --quiet

export FINAL_URL=$(gcloud run services describe $ADK_SERVICE_NAME --region=$LOCATION --format="value(status.url)")

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${CYAN}${BOLD}YOUR LIVE CLOUD RUN URL: ${FINAL_URL}${RESET}"
echo -e "${WHITE}${BOLD}Now follow Steps 4, 5, and 6 in the blog instructions to secure your final points!${RESET}"
