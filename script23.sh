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
# Auto-Fetching Variables
# ----------------------------------------------------------------------
export PROJECT_ID=$(gcloud config get-value project)
export LOCATION=$(gcloud config get-value compute/region 2>/dev/null)
export STUDENT_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

if [ -z "$LOCATION" ] || [ "$LOCATION" == "(unset)" ]; then
    export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
    export LOCATION=${ZONE%-*}
fi

if [ -z "$LOCATION" ] || [ "$LOCATION" == "(unset)" ]; then
    echo -e "${YELLOW}${BOLD}Region not found automatically.${RESET}"
    read -p "Please paste the REGION from your lab instructions and press Enter: " LOCATION
fi

echo -e "${CYAN}${BOLD}Project: $PROJECT_ID${RESET}"
echo -e "${CYAN}${BOLD}Region: $LOCATION${RESET}"
echo -e "${CYAN}${BOLD}Student Email: $STUDENT_EMAIL${RESET}\n"

# ----------------------------------------------------------------------
# Task 1 & 2: Setup and IAM
# ----------------------------------------------------------------------
echo -e "${YELLOW}${BOLD}Enabling necessary APIs...${RESET}"
gcloud services enable \
    aiplatform.googleapis.com \
    artifactregistry.googleapis.com \
    compute.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com

echo -e "${YELLOW}${BOLD}Applying IAM Policy Bindings...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="user:$STUDENT_EMAIL" --role="roles/run.admin" --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member="user:$STUDENT_EMAIL" --role="roles/aiplatform.user" --quiet

echo -e "${YELLOW}${BOLD}Downloading and extracting boilerplate code...${RESET}"
cd ~
gcloud storage cp gs://$PROJECT_ID-labconfig-bucket/labs_code.zip .
unzip -o labs_code.zip

# ----------------------------------------------------------------------
# Task 3: Fix and Deploy MCP Server
# ----------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Fixing and testing local MCP Server...${RESET}"
cd ~/mcp-on-cloudrun
sed -i 's/# mcp = FastMCP/mcp = FastMCP/g' server.py

uv run server.py &
SERVER_PID=$!
sleep 10
kill $SERVER_PID
uv run local_mcp_call.py

echo -e "\n${YELLOW}${BOLD}Deploying MCP Server to Cloud Run... (This takes a few minutes)${RESET}"
gcloud run deploy coding-zoo-mcp-server \
    --no-allow-unauthenticated \
    --region=$LOCATION \
    --source=. \
    --min=1 \
    --project=$PROJECT_ID \
    --labels=lab-dev=mcp-zoo-cloud-run-service \
    --quiet

# ----------------------------------------------------------------------
# Task 4: Configure Gemini CLI and Agent 
# ----------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Configuring Gemini CLI Settings...${RESET}"
export CLOUD_RUN_URL=$(gcloud run services describe coding-zoo-mcp-server --region=$LOCATION --format="value(status.url)")
export ID_TOKEN=$(gcloud auth print-identity-token)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

mkdir -p ~/.gemini
cat <<EOF > ~/.gemini/settings.json
{
  "mcpServers": {
    "zoo-remote": {
      "httpUrl": "${CLOUD_RUN_URL}/mcp/",
      "headers": {
        "Authorization": "Bearer ${ID_TOKEN}"
      }
    }
  },
  "selectedAuthType": "compute-default-credentials",
  "hasSeenIdeIntegrationNudge": true
}
EOF

echo -e "\n${YELLOW}${BOLD}Automating Gemini CLI checks (Running in background)...${RESET}"
pip install pexpect --quiet
cat << 'EOF' > ~/test_gemini.py
import pexpect
import sys
import time

print("Starting Gemini CLI automation...")
child = pexpect.spawn('gemini', encoding='utf-8', timeout=60)
child.logfile = sys.stdout

while True:
    index = child.expect(['>', 'Press Enter', pexpect.EOF, pexpect.TIMEOUT], timeout=10)
    if index == 0:
        break
    elif index == 1:
        child.sendline('')
    else:
        break

child.sendline('Where can I find penguins?')
index = child.expect(['Allow execution of MCP tool', '>'], timeout=15)
if index == 0:
    child.sendline('3')
    child.expect('>')

child.sendline('/find --animal="lion"')
index = child.expect(['Allow execution of MCP tool', '>'], timeout=15)
if index == 0:
    child.sendline('3')
    child.expect('>')

child.sendline('/quit')
print("Gemini CLI automation complete.")
EOF
python3 ~/test_gemini.py

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

sed -i 's/.*\[TODO\].*Add your code here.*/    tools=[google_search]/g' agent.py

# ----------------------------------------------------------------------
# Task 5: Deploy ADK Agent
# ----------------------------------------------------------------------
echo -e "\n${YELLOW}${BOLD}Deploying ADK Agent to Cloud Run (This takes a few minutes)...${RESET}"
python -m venv .venv
source .venv/bin/activate
pip install --no-cache-dir -r requirements.txt

adk deploy cloud_run \
  --project=$PROJECT_ID \
  --region=$LOCATION \
  --service_name=zoo-tour-guide \
  --with_ui \
  . \
  -- \
  --labels=lab-dev=cloud-zoo-run-adk-service \
  --quiet

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
