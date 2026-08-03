#!/bin/bash
# ==============================================================================
# Orbit of Ops - Master Script
# Lab: GSP393 - Implement CI/CD Pipelines on Google Cloud: Challenge Lab
# ==============================================================================

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
echo -e "${BLUE}${BOLD}║   🌊 WELCOME TO Orbit Of Ops                               ║${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 TARGET: GSP393 CI/CD PIPELINES CHALLENGE LAB          ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project, Zone, and Region...${RESET}"
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)' 2>/dev/null)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)

if [[ -z "$ZONE" ]]; then
    echo -e "${BOLD}${MAGENTA}⚠️ Could not auto-detect the default zone via gcloud metadata.${RESET}"
    read -p "$(echo -e ${BOLD}${CYAN}"Please enter the lab Zone (e.g., us-east1-c): "${RESET})" ZONE
    export ZONE
fi

export REGION=${ZONE%-*}

gcloud config set compute/zone $ZONE 2>/dev/null
gcloud config set compute/region $REGION 2>/dev/null

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Zone:       ${GREEN}$ZONE${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"

# ==============================================================================
# TASK 1: SETUP, IAM, BUCKET & CLUSTERS
# ==============================================================================
echo -e "${GREEN}${BOLD}▬▬▬▬▬▬ TASK 1: ENVIRONMENT SETUP ▬▬▬▬▬▬${RESET}"
echo -e "${YELLOW}[*] Enabling APIs & Configuring IAM...${RESET}"
gcloud services enable container.googleapis.com clouddeploy.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/clouddeploy.jobRunner" --quiet >/dev/null

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/container.developer" --quiet >/dev/null

echo -e "${YELLOW}[*] Creating Storage Bucket & Artifact Registry...${RESET}"
gsutil mb -p $PROJECT_ID gs://${PROJECT_ID}_cloudbuild >/dev/null 2>&1
gcloud artifacts repositories create cicd-challenge --repository-format=docker --location=$REGION --quiet

echo -e "${YELLOW}[*] Provisioning GKE Clusters (This will take ~3-5 mins)...${RESET}"
gcloud container clusters create cd-staging --zone=$ZONE --num-nodes=1 --async --quiet
gcloud container clusters create cd-production --zone=$ZONE --num-nodes=1 --async --quiet

# ==============================================================================
# TASK 2: BUILD IMAGE
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 2: BUILD IMAGE ▬▬▬▬▬▬${RESET}"
echo -e "${YELLOW}[*] Cloning repository and building container image...${RESET}"
cd ~/
git clone https://github.com/GoogleCloudPlatform/cloud-deploy-tutorials.git >/dev/null 2>&1
cd cloud-deploy-tutorials
git checkout c3cae80 --quiet
cd tutorials/base

envsubst < clouddeploy-config/skaffold.yaml.template > web/skaffold.yaml

gcloud auth configure-docker $REGION-docker.pkg.dev --quiet >/dev/null 2>&1

cd web
skaffold build --interactive=false --default-repo $REGION-docker.pkg.dev/$PROJECT_ID/cicd-challenge --file-output artifacts.json >/dev/null 2>&1
cd ..

# ==============================================================================
# TASK 3: DELIVERY PIPELINE & TARGETS
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 3: DELIVERY PIPELINE & TARGETS ▬▬▬▬▬▬${RESET}"
echo -e "${YELLOW}[*] Waiting for GKE Clusters to finish provisioning...${RESET}"
CLUSTERS=("cd-staging" "cd-production")
for cluster in "${CLUSTERS[@]}"; do
  while true; do
    STATUS=$(gcloud container clusters describe "$cluster" --zone=$ZONE --format="value(status)" 2>/dev/null)
    if [[ "$STATUS" == "RUNNING" ]]; then break; fi
    sleep 10
  done
done

echo -e "${YELLOW}[*] Configuring Kubectl Contexts & Namespaces...${RESET}"
for CONTEXT in "${CLUSTERS[@]}"; do
    gcloud container clusters get-credentials ${CONTEXT} --zone ${ZONE} --quiet
    kubectl config rename-context gke_${PROJECT_ID}_${ZONE}_${CONTEXT} ${CONTEXT} >/dev/null 2>&1
    kubectl --context ${CONTEXT} apply -f kubernetes-config/web-app-namespace.yaml >/dev/null 2>&1
done

echo -e "${YELLOW}[*] Configuring and Applying Cloud Deploy Pipeline...${RESET}"
cp clouddeploy-config/delivery-pipeline.yaml.template clouddeploy-config/delivery-pipeline.yaml
sed -i "s/targetId: staging/targetId: cd-staging/" clouddeploy-config/delivery-pipeline.yaml
sed -i "s/targetId: prod/targetId: cd-production/" clouddeploy-config/delivery-pipeline.yaml
sed -i "/targetId: test/d" clouddeploy-config/delivery-pipeline.yaml

gcloud config set deploy/region $REGION >/dev/null 2>&1
gcloud deploy apply --file=clouddeploy-config/delivery-pipeline.yaml --quiet

envsubst < clouddeploy-config/target-staging.yaml.template > clouddeploy-config/target-cd-staging.yaml
envsubst < clouddeploy-config/target-prod.yaml.template > clouddeploy-config/target-cd-production.yaml

sed -i "s/staging/cd-staging/" clouddeploy-config/target-cd-staging.yaml
sed -i "s/prod/cd-production/" clouddeploy-config/target-cd-production.yaml
sed -i "s|cluster: .*|cluster: projects/$PROJECT_ID/locations/$ZONE/clusters/cd-staging|" clouddeploy-config/target-cd-staging.yaml
sed -i "s|cluster: .*|cluster: projects/$PROJECT_ID/locations/$ZONE/clusters/cd-production|" clouddeploy-config/target-cd-production.yaml

gcloud deploy apply --file clouddeploy-config/target-cd-staging.yaml --quiet
gcloud deploy apply --file clouddeploy-config/target-cd-production.yaml --quiet

# ==============================================================================
# TASK 4: CREATE RELEASE
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 4: DEPLOYING RELEASE 001 ▬▬▬▬▬▬${RESET}"
gcloud deploy releases create web-app-001 --delivery-pipeline web-app --build-artifacts web/artifacts.json --source web/ --quiet

echo -e "${YELLOW}[*] Waiting for Rollout 001 to SUCCEED in Staging...${RESET}"
while true; do
  STATUS=$(gcloud deploy rollouts list --delivery-pipeline web-app --release web-app-001 --format="value(state)" | head -n 1)
  if [[ "$STATUS" == "SUCCEEDED" ]]; then
    echo -e "✅ Staging Rollout 001 is ${GREEN}SUCCEEDED${RESET}."
    break
  fi
  sleep 10
done

# ==============================================================================
# TASK 5: PROMOTE TO PRODUCTION
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 5: PROMOTING TO PRODUCTION ▬▬▬▬▬▬${RESET}"
gcloud deploy releases promote --delivery-pipeline web-app --release web-app-001 --quiet

while true; do
  STATUS=$(gcloud deploy rollouts list --delivery-pipeline web-app --release web-app-001 --format="value(state)" | head -n 1)
  if [[ "$STATUS" == "PENDING_APPROVAL" ]]; then break; fi
  sleep 5
done

gcloud deploy rollouts approve web-app-001-to-cd-production-0001 --delivery-pipeline web-app --release web-app-001 --quiet

echo -e "${YELLOW}[*] Waiting for Production Rollout to SUCCEED...${RESET}"
while true; do
  STATUS=$(gcloud deploy rollouts list --delivery-pipeline web-app --release web-app-001 --format="value(state)" | head -n 1)
  if [[ "$STATUS" == "SUCCEEDED" ]]; then
    echo -e "✅ Production Rollout 001 is ${GREEN}SUCCEEDED${RESET}."
    break
  fi
  sleep 10
done

# ==============================================================================
# TASK 6: MODIFY APP & REDEPLOY (V2)
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 6: MODIFYING APP TO V2 & REDEPLOYING ▬▬▬▬▬▬${RESET}"
sed -i 's/leeroooooy app!!/leeroooooy app v2!!/g' web/leeroy-app/app.go

cd web
skaffold build --interactive=false --default-repo $REGION-docker.pkg.dev/$PROJECT_ID/cicd-challenge --file-output artifacts.json >/dev/null 2>&1
cd ..

gcloud deploy releases create web-app-002 --delivery-pipeline web-app --build-artifacts web/artifacts.json --source web/ --quiet

echo -e "${YELLOW}[*] Waiting for Rollout 002 to SUCCEED in Staging...${RESET}"
while true; do
  STATUS=$(gcloud deploy rollouts list --delivery-pipeline web-app --release web-app-002 --format="value(state)" | head -n 1)
  if [[ "$STATUS" == "SUCCEEDED" ]]; then
    echo -e "✅ Staging Rollout 002 is ${GREEN}SUCCEEDED${RESET}."
    break
  fi
  sleep 10
done

# ==============================================================================
# TASK 7: ROLLBACK
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 7: EXECUTING ROLLBACK ▬▬▬▬▬▬${RESET}"
gcloud deploy targets rollback cd-staging --delivery-pipeline=web-app --quiet

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
