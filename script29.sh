clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
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
echo -e "${BLUE}${BOLD}║   🚀 BROUGHT TO YOU BY ORBIT OF OPS                        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project)
export REGION=$(gcloud config get-value compute/region 2>/dev/null)
if [ -z "$REGION" ] || [ "$REGION" == "(unset)" ]; then
    export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
    export REGION=${ZONE%-*}
fi
if [ -z "$REGION" ] || [ "$REGION" == "(unset)" ]; then
    read -p "Please paste the REGION from your lab instructions (e.g. us-central1) and press Enter: " REGION </dev/tty
fi
gcloud config set compute/region $REGION

# Gather the Tester Email before we begin
read -p "Please paste the 'Tester' email from your lab panel and press Enter: " TESTER_EMAIL

echo "1️⃣ Enabling IAP API & Deploying App Engine..."
gcloud services enable iap.googleapis.com
git clone https://github.com/GoogleCloudPlatform/python-docs-samples.git
cd python-docs-samples/appengine/standard_python3/hello_world/
gcloud app create --project=$PROJECT_ID --region=$REGION
gcloud app deploy --quiet

echo "=========================================================================="
echo "⚠️ MANUAL UI STEPS REQUIRED FOR OAUTH AND IAP ⚠️"
echo "1. Go to APIs & Services > OAuth consent screen."
echo "   - Choose 'External' -> Create."
echo "   - Fill App Name and the 2 required emails. Save & Continue to the end."
echo "2. Go to Security > Identity-Aware Proxy."
echo "   - Toggle IAP 'ON' for the App Engine app."
echo "=========================================================================="
read -p "Press Enter ONLY when you have completed the manual UI steps..."

echo "2️⃣ Applying IAM Roles for Tester Account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="user:$TESTER_EMAIL" \
    --role="roles/iap.httpsResourceAccessor"

MAGENTA='\e[1;35m'
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"

# Subscribe to Orbit of Ops https://www.youtube.com/@orbitofops/videos
