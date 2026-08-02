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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Execution (GSP318)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project, Zone, and Region...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo -e "${BOLD}${RED}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    echo -ne "${BOLD}${CYAN}Please enter the lab Zone (e.g., us-east1-c): ${RESET}"
    read ZONE
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
# USER INPUT
# ==============================================================================
echo -e "${BOLD}${YELLOW}⚠️ ATTENTION: Check your lab instructions for the following values: ${RESET}"

echo -ne "${BOLD}${CYAN}Enter the Docker Image Name (from Task 1): ${RESET}"
read IMAGE_NAME

echo -ne "${BOLD}${CYAN}Enter the Docker Tag Name (from Task 1): ${RESET}"
read TAG_NAME

echo -ne "${BOLD}${CYAN}Enter the Artifact Registry Repository Name (from Task 3): ${RESET}"
read REPOSITORY_NAME

echo -e "\n${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Initializing lab grading scripts...${RESET}"
source <(gsutil cat gs://spls/gsp318/script.sh)

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Downloading source code and creating Dockerfile...${RESET}"
gsutil cp gs://spls/gsp318/valkyrie-app.tgz .
tar -xzf valkyrie-app.tgz
cd valkyrie-app

cat > Dockerfile <<EOF
FROM golang:1.10
WORKDIR /go/src/app
COPY source .
RUN go install -v
ENTRYPOINT ["app","-single=true","-port=8080"]
EOF

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Building local Docker image...${RESET}"
docker build -t $IMAGE_NAME:$TAG_NAME .

# Run local grading scripts if they exist
cd ..
[ -f step1.sh ] && bash step1.sh
[ -f step1_v2.sh ] && bash step1_v2.sh
cd valkyrie-app

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Testing Docker image locally...${RESET}"
docker run -d -p 8080:8080 $IMAGE_NAME:$TAG_NAME

# Run local grading scripts if they exist
cd ..
[ -f step2.sh ] && bash step2.sh
[ -f step2_v2.sh ] && bash step2_v2.sh
cd valkyrie-app

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Creating Artifact Registry and configuring Docker auth...${RESET}"
gcloud artifacts repositories create $REPOSITORY_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Valkyrie App Repository" \
    --quiet

gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Tagging and pushing image to Artifact Registry...${RESET}"
docker tag $IMAGE_NAME:$TAG_NAME $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$IMAGE_NAME:$TAG_NAME
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$IMAGE_NAME:$TAG_NAME

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 4: Creating and exposing Kubernetes deployment...${RESET}"
sed -i "s|IMAGE_HERE|$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$IMAGE_NAME:$TAG_NAME|g" k8s/deployment.yaml

gcloud container clusters get-credentials valkyrie-dev --zone $ZONE --quiet

kubectl create -f k8s/deployment.yaml
kubectl create -f k8s/service.yaml

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
