GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'
RED='\e[1;31m'
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
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC131 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export ZONE=$(gcloud compute instances list --format="value(zone)" | head -n 1)
export VM_NAME=$(gcloud compute instances list --format="value(name)" | head -n 1)

echo -e "${CYAN}${BOLD}[*] Auto-generating restricted API Key via CLI...${RESET}"
gcloud services enable apikeys.googleapis.com speech.googleapis.com --quiet
sleep 5

gcloud services api-keys create \
    --display-name="OrbitKey" \
    --api-target=service=speech.googleapis.com \
    --quiet 2>/dev/null
sleep 5

export API_KEY=$(gcloud services api-keys get-key-string \
    $(gcloud services api-keys list --filter="display_name='OrbitKey'" --format="value(name)" | head -n 1) \
    --format="value(keyString)" 2>/dev/null)

if [ -z "$API_KEY" ]; then
    echo -e "\n${RED}${BOLD}[!] Auto-generation blocked by Qwiklabs. Please create the API key manually in the UI and enter it below:${RESET}"
    read -p "Enter API Key: " API_KEY
else
    echo -e "${GREEN}${BOLD}[*] API Key successfully generated: ${API_KEY}${RESET}\n"
fi

echo -e "${YELLOW}${BOLD}Please enter the specific variables from your lab manual:${RESET}"
read -p "Enter Task 2 Request File Name: " REQUEST1
read -p "Enter Task 2 Response File Name: " RESPONSE1
read -p "Enter Task 3 Request File Name: " REQUEST2
read -p "Enter Task 3 Response File Name: " RESPONSE2
echo ""

echo -e "${CYAN}${BOLD}[*] Compiling Remote Execution Payload...${RESET}"

cat > remote_payload.sh <<EOF
#!/bin/bash
export API_KEY="${API_KEY}"
export REQUEST1="${REQUEST1}"
export RESPONSE1="${RESPONSE1}"
export REQUEST2="${REQUEST2}"
export RESPONSE2="${RESPONSE2}"
EOF

cat >> remote_payload.sh <<'EOF_SCRIPT'
echo "--> [Task 2] Generating English Audio Request JSON..."
cat > "$REQUEST1" <<EOF
{
  "config": {
    "encoding": "LINEAR16",
    "languageCode": "en-US",
    "audioChannelCount": 2
  },
  "audio": {
    "uri": "gs://spls/arc131/question_en.wav"
  }
}
EOF

echo "--> [Task 2] Calling Speech-to-Text API (English)..."
curl -s -X POST -H "Content-Type: application/json" --data-binary @"$REQUEST1" \
"https://speech.googleapis.com/v1/speech:recognize?key=$API_KEY" > "$RESPONSE1"

echo "--> [Task 3] Generating Spanish Audio Request JSON..."
cat > "$REQUEST2" <<EOF
{
  "config": {
    "encoding": "FLAC",
    "languageCode": "es-ES"
  },
  "audio": {
    "uri": "gs://spls/arc131/multi_es.flac"
  }
}
EOF

echo "--> [Task 3] Calling Speech-to-Text API (Spanish)..."
curl -s -X POST -H "Content-Type: application/json" --data-binary @"$REQUEST2" \
"https://speech.googleapis.com/v1/speech:recognize?key=$API_KEY" > "$RESPONSE2"
EOF_SCRIPT

echo -e "${YELLOW}${BOLD}[*] Deploying and Executing Payload on ${VM_NAME}...${RESET}"
gcloud compute scp remote_payload.sh $VM_NAME:~ --zone=$ZONE --quiet
gcloud compute ssh $VM_NAME --zone=$ZONE --quiet --command="bash ~/remote_payload.sh"

rm remote_payload.sh

echo -e "\n${GREEN}${BOLD}>>> MISSION COMPLETE! Check all progress bars in Qwiklabs. <<<${RESET}"
