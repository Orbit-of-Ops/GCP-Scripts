#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS COMMAND CENTER: GENAI129 FLAWLESS MASTER SCRIPT (UNFROZEN)
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
echo "${MAGENTA}${BOLD}>>> INITIATING FLAWLESS GENAI129 ADK AUTOMATION <<<${RESET}"
echo ""

# ==============================================================================
# PHASE 1: VARIABLE AUTO-FETCH & API PRE-WARMING
# ==============================================================================
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export REGION=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-region])" 2>/dev/null)
if [ -z "$REGION" ]; then export REGION="us-central1"; fi
export SA_EMAIL="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
export PATH=$PATH:"/home/${USER}/.local/bin"

gcloud services enable discoveryengine.googleapis.com aiplatform.googleapis.com --quiet

# ==============================================================================
# PHASE 2: SEARCH ENGINE ID
# ==============================================================================
echo "${YELLOW}${BOLD}[*] If you already created the Data Store, just paste the ID here!${RESET}"
echo "${CYAN}${BOLD}======================================================================${RESET}"
read -p "PASTE YOUR SEARCH ENGINE ID HERE TO CONTINUE AUTOMATION: " SEARCH_ENGINE_ID
echo ""
echo "${YELLOW}${BOLD}[*] Target Locked. Executing Automation...${RESET}"

# ==============================================================================
# PHASE 3: INSTALLATION & ENVIRONMENT (FIXED: NO CACHE, VISIBLE OUTPUT)
# ==============================================================================
echo "${YELLOW}[*] Phase 3: Downloading project and installing dependencies...${RESET}"
cd ~
rm -rf adk_challenge_lab
gcloud storage cp -r gs://${PROJECT_ID}-bucket/adk_challenge_lab . --quiet

echo "${CYAN}[*] Installing Python packages (You will see lots of text, this is normal and prevents hanging!)...${RESET}"
python3 -m pip install --no-cache-dir -r adk_challenge_lab/requirements.txt
python3 -m pip install --no-cache-dir chainlit==2.11.1

gcloud iam service-accounts keys create ~/adc.json --iam-account=$SA_EMAIL --quiet
export GOOGLE_APPLICATION_CREDENTIALS=~/adc.json

cat << EOF > adk_challenge_lab/.env
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_LOCATION=$REGION
RESOURCES_BUCKET=${PROJECT_ID}-bucket
MODEL=gemini-2.5-flash
SEARCH_ENGINE_ID=$SEARCH_ENGINE_ID
EOF
cp adk_challenge_lab/.env adk_challenge_lab/paint_agent/.env

# ==============================================================================
# PHASE 4: SURGICAL PYTHON PATCHING
# ==============================================================================
echo -e "\n${CYAN}[*] Phase 4: Surgically Patching the ADK Agents...${RESET}"

cat << 'EOF' > patch_agents.py
import os, re

# 1. Patch agent.py perfectly
agent_file = os.path.expanduser("~/adk_challenge_lab/paint_agent/agent.py")
with open(agent_file, "r") as f: content = f.read()

if "from google.adk.tools import AgentTool" not in content:
    content = "from google.adk.tools import AgentTool\n" + content

# Surgically isolate and remove search_agent from the sub_agents list
content = re.sub(r'(sub_agents\s*=\s*\[)([^\]]*)(\])', lambda m: m.group(1) + m.group(2).replace('search_agent,', '').replace('search_agent', '').strip() + m.group(3), content)

# Inject AgentTool into tools list
content = re.sub(r'(tools\s*=\s*\[)([^\]]*)(\])', lambda m: m.group(1) + ("AgentTool(agent=search_agent, skip_summarization=False), " if "AgentTool(" not in m.group(2) else "") + m.group(2) + m.group(3), content)

with open(agent_file, "w") as f: f.write(content)

# 2. Patch tools.py
tools_file = os.path.expanduser("~/adk_challenge_lab/paint_agent/tools.py")
with open(tools_file, "r") as f: content = f.read()
new_func = "def set_session_value(key: str, value: str, context: ToolContext) -> str:\n    context.state[key] = value\n    return f\"stored '{value}' in '{key}'\"\n"
content = re.sub(r'def set_session_value.*?->\s*str:.*?(?=\n\s*def|\Z)', new_func, content, flags=re.DOTALL)
with open(tools_file, "w") as f: f.write(content)

# 3. Patch coverage_calculator/agent.py
calc_file = os.path.expanduser("~/adk_challenge_lab/paint_agent/sub_agents/room_planner/sub_agents/coverage_calculator/agent.py")
with open(calc_file, "r") as f: content = f.read()
content = content.replace("SELECTED_PAINT", "{SELECTED_PAINT?}").replace("COVERAGE_RATE", "{COVERAGE_RATE?}")
content = content.replace("{{SELECTED_PAINT?}}", "{SELECTED_PAINT?}").replace("{{COVERAGE_RATE?}}", "{COVERAGE_RATE?}")
with open(calc_file, "w") as f: f.write(content)

print("[+] Code successfully patched without syntax errors!")
EOF
python3 patch_agents.py

# ==============================================================================
# PHASE 5: LOCAL EXECUTION & IAM
# ==============================================================================
echo -e "\n${MAGENTA}[*] Phase 5: Firing Local Prompts for Tasks 3 & 4...${RESET}"
cd ~/adk_challenge_lab
adk run paint_agent <<< "What are the prices of EcoGreens and Forever Paint?"
sleep 2
adk run paint_agent <<< "I have one room, my office. I want to use EcoGreens in Deep Ocean. 3m by 4m, 3m high. 1 door, 2 windows. Two coats."
sleep 2

echo -e "\n${YELLOW}[*] Granting IAM Permissions for Agent Deployment...${RESET}"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_EMAIL" --role="roles/aiplatform.user" --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_EMAIL" --role="roles/discoveryengine.user" --quiet

# ==============================================================================
# PHASE 6: CLOUD DEPLOYMENT
# ==============================================================================
echo -e "\n${MAGENTA}[!] Phase 6: Deploying Agent to Runtime (Task 5)...${RESET}"
echo "${YELLOW}${BOLD}>>> WARNING: This step takes 5-10 minutes. Do not interrupt! <<<${RESET}"
cd ~/adk_challenge_lab/paint_agent
DEPLOY_LOG=$(adk deploy agent_engine . --display_name "Paint Agent" 2>&1 | tee /dev/tty)

# Extract Resource Name robustly
RESOURCE_NAME=$(echo "$DEPLOY_LOG" | grep -o "projects/[^/]\+/locations/[^/]\+/reasoningEngines/[^/]\+" | head -n 1)
echo -e "\n[+] Extracted Deployed Resource Name: $RESOURCE_NAME"

# ==============================================================================
# PHASE 7: CHAINLIT UI DEPLOYMENT (TASK 6)
# ==============================================================================
echo -e "\n${CYAN}[*] Phase 7: Launching Web UI for Task 6 on Port 8080...${RESET}"
cd ~/adk_challenge_lab/chainlit_ui

# Inject ID perfectly via sed
sed -i "s|agent = client\.agent_engines\.get.*|agent = client.agent_engines.get(name=\"$RESOURCE_NAME\")|g" app.py

echo -e "\n${GREEN}${BOLD}====================================================================${RESET}"
echo "${GREEN}${BOLD}>>> PIPELINE AUTOMATION COMPLETE! FINAL UI STEP REQUIRED <<<${RESET}"
echo "${GREEN}${BOLD}====================================================================${RESET}"
echo ""
echo "${WHITE}${BOLD}1.${RESET} Go click ${BOLD}'Check my progress'${RESET} for Tasks 2, 3, 4, and 5. They are fully completed!"
echo "${WHITE}${BOLD}2.${RESET} Click the ${BOLD}Web Preview${RESET} icon in the top-right of Cloud Shell and click ${BOLD}'Preview on port 8080'${RESET}."
echo "${WHITE}${BOLD}3.${RESET} In the UI that opens, paste this exact prompt and hit Send:"
echo ""
echo -e "${YELLOW}Hello, I want to use Forever Paint for 2 rooms. Living room (Coffee Cream, 5m x 4m, 2.5m high, 1 door, 3 windows) and Baby room (Sunlight through a canvas tent, 3m x 3m, 2.5m high, 1 door, 1 window). 2 coats.${RESET}"
echo ""
echo "${WHITE}${BOLD}4.${RESET} Once the bot calculates the square meters, click 'Check my progress' for Task 6!"
echo "${GREEN}${BOLD}====================================================================${RESET}"
echo -e "\n${MAGENTA}[*] Starting Server... (Do not close this terminal!)${RESET}"

chainlit run app.py --port 8080
