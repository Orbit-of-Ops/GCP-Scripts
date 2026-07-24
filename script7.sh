#!/bin/bash
clear

# ==============================================================================
# ORBIT OF OPS: GSP364 MASTER SCRIPT (CREDIT-SAFE)
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
echo "${MAGENTA}${BOLD}>>> ORBIT OF OPS: GSP364 MASTER SCRIPT <<<${RESET}"
echo "${GREEN}${BOLD}>>> ANTI-BAN & MANAGED PROMETHEUS PROTOCOLS: ACTIVE <<<${RESET}"
echo ""

echo "${CYAN}${BOLD}[*] Scanning Qwiklabs environment for Zone data...${RESET}"
ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
if [ -z "$ZONE" ]; then
    ZONE=$(gcloud config get-value compute/zone)
fi
PROJECT=$(gcloud config get-value project)
echo "${YELLOW}Zone identified:${RESET} ${WHITE}${ZONE}${RESET}"
echo "${YELLOW}Project identified:${RESET} ${WHITE}${PROJECT}${RESET}"
echo ""

echo "${GREEN}${BOLD}[*] Task 1: Deploying GKE Cluster with Managed Prometheus Flag...${RESET}"
echo "${YELLOW}(Note: Cluster creation takes 5-7 minutes. Do not close this terminal!)${RESET}"
gcloud beta container clusters create gmp-cluster \
    --num-nodes=2 \
    --zone=$ZONE \
    --enable-managed-prometheus \
    --quiet

echo "${GREEN}${BOLD}[*] Task 2: Fetching Credentials and Deploying Managed Collection...${RESET}"
gcloud container clusters get-credentials gmp-cluster --zone=$ZONE
sleep 2

kubectl create ns gmp-test
sleep 2

kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/manifests/setup.yaml
sleep 3

kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/manifests/operator.yaml
sleep 3

echo "${GREEN}${BOLD}[*] Task 3: Deploying Example Application...${RESET}"
kubectl -n gmp-test apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.2.3/examples/example-app.yaml
sleep 3

echo "${GREEN}${BOLD}[*] Task 4: Filtering Exported Metrics and Uploading to GCS...${RESET}"
# Creating a clean YAML config without the old broken metadata
cat > op-config.yaml <<EOF
apiVersion: monitoring.googleapis.com/v1alpha1
kind: OperatorConfig
metadata:
  namespace: gmp-public
  name: config
collection:
  filter:
    matchOneOf:
    - '{job="prom-example"}'
    - '{__name__=~"job:.+"}'
EOF

echo "${CYAN}[*] Creating Cloud Storage Bucket and uploading config...${RESET}"
gsutil mb -p $PROJECT gs://$PROJECT
gsutil cp op-config.yaml gs://$PROJECT/
gsutil -m acl set -R -a public-read gs://$PROJECT/

echo -e "\n${MAGENTA}${BOLD}====================================================================${RESET}"
echo "${MAGENTA}${BOLD}>>> SCRIPT COMPLETE! You may now click 'Check my progress' on ALL tasks! <<<${RESET}"
echo "${MAGENTA}${BOLD}====================================================================${RESET}"
