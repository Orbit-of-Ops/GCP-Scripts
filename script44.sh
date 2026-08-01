#!/bin/bash
set +H
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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (GSP313)... ${RESET}"
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
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Task 1: Creating multiple web server instances (web1, web2, web3)...${RESET}"
for i in 1 2 3; do
  gcloud compute instances create web$i \
    --zone=$ZONE \
    --machine-type=e2-small \
    --tags=network-lb-tag \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      service apache2 restart
      echo "<h3>Web Server: web'$i'</h3>" | tee /var/www/html/index.html' --quiet &
done
wait
echo -e "${GREEN}✅ Web instances created.${RESET}"

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Creating firewall rule for instances...${RESET}"
gcloud compute firewall-rules create www-firewall-network-lb \
    --allow tcp:80 \
    --target-tags network-lb-tag \
    --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Configuring the Network Load Balancing Service...${RESET}"
gcloud compute addresses create network-lb-ip-1 --region=$REGION --quiet
gcloud compute http-health-checks create basic-check --quiet
gcloud compute target-pools create www-pool --region=$REGION --http-health-check basic-check --quiet
gcloud compute target-pools add-instances www-pool --instances web1,web2,web3 --zone=$ZONE --quiet
gcloud compute forwarding-rules create www-rule \
    --region=$REGION \
    --ports 80 \
    --address network-lb-ip-1 \
    --target-pool www-pool \
    --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Creating the HTTP Load Balancer...${RESET}"
echo -e "${YELLOW}Creating Instance Template...${RESET}"
gcloud compute instance-templates create lb-backend-template \
   --region=$REGION \
   --network=default \
   --subnet=default \
   --tags=allow-health-check \
   --machine-type=e2-medium \
   --image-family=debian-12 \
   --image-project=debian-cloud \
   --metadata=startup-script='#!/bin/bash
     apt-get update
     apt-get install apache2 -y
     a2ensite default-ssl
     a2enmod ssl
     vm_hostname="$(curl -H "Metadata-Flavor:Google" http://169.254.169.254/computeMetadata/v1/instance/name)"
     echo "Page served from: $vm_hostname" | tee /var/www/html/index.html
     systemctl restart apache2' --quiet

echo -e "${YELLOW}Creating Managed Instance Group...${RESET}"
gcloud compute instance-groups managed create lb-backend-group \
   --template=lb-backend-template \
   --size=2 \
   --zone=$ZONE \
   --quiet

echo -e "${YELLOW}Setting Managed Instance Group Named Ports...${RESET}"
gcloud compute instance-groups managed set-named-ports lb-backend-group \
   --named-ports=http:80 \
   --zone=$ZONE \
   --quiet

echo -e "${YELLOW}Creating Health Check Firewall Rule...${RESET}"
gcloud compute firewall-rules create fw-allow-health-check \
  --network=default \
  --action=allow \
  --direction=ingress \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=allow-health-check \
  --rules=tcp:80 \
  --quiet

echo -e "${YELLOW}Allocating Global IP Address...${RESET}"
gcloud compute addresses create lb-ipv4-1 --ip-version=IPV4 --global --quiet

echo -e "${YELLOW}Creating HTTP Health Check...${RESET}"
gcloud compute health-checks create http http-basic-check --port 80 --quiet

echo -e "${YELLOW}Configuring Backend Services...${RESET}"
gcloud compute backend-services create web-backend-service \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=http-basic-check \
  --global \
  --quiet

gcloud compute backend-services add-backend web-backend-service \
  --instance-group=lb-backend-group \
  --instance-group-zone=$ZONE \
  --global \
  --quiet

echo -e "${YELLOW}Creating URL Map and Target Proxy...${RESET}"
gcloud compute url-maps create web-map-http \
    --default-service web-backend-service \
    --quiet

gcloud compute target-http-proxies create http-lb-proxy \
    --url-map web-map-http \
    --quiet

echo -e "${YELLOW}Creating Global Forwarding Rule...${RESET}"
gcloud compute forwarding-rules create http-content-rule \
    --address=lb-ipv4-1 \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80 \
    --quiet

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${YELLOW}${BOLD}⚠️ IMPORTANT: Global HTTP Load Balancers take 3 to 5 minutes to fully initialize.${RESET}"
echo -e "${GREEN}${BOLD}Please wait 5 minutes before clicking 'Check my progress' for Task 3.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
