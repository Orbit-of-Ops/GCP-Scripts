clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
RESET='\e[0m'
BOLD='\e[1m'
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'

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

echo "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project ID...${RESET}"
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi
echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}\n"

echo -e "${MAGENTA}${BOLD}Please copy and paste the following values from your lab instructions:${RESET}"
read -p "Enter Network Name: " VPC_NAME
read -p "Enter Subnet A Name: " SUBNET_A
read -p "Enter Subnet B Name: " SUBNET_B
read -p "Enter Firewall Rule 1 Name (SSH): " FW_1
read -p "Enter Firewall Rule 2 Name (RDP): " FW_2
read -p "Enter Firewall Rule 3 Name (ICMP): " FW_3
read -p "Enter Zone 1 (For Subnet A, e.g., us-central1-a): " ZONE_1
read -p "Enter Zone 2 (For Subnet B, e.g., us-east1-b): " ZONE_2
echo ""

export REGION_1=${ZONE_1%-*}
export REGION_2=${ZONE_2%-*}

echo -e "${YELLOW}Starting Infrastructure Provisioning...${RESET}"

echo -e "${CYAN}Creating VPC Network: $VPC_NAME...${RESET}"
gcloud compute networks create $VPC_NAME \
    --project=$PROJECT_ID \
    --subnet-mode=custom \
    --bgp-routing-mode=regional

echo -e "${CYAN}Creating Subnet A: $SUBNET_A...${RESET}"
gcloud compute networks subnets create $SUBNET_A \
    --project=$PROJECT_ID \
    --region=$REGION_1 \
    --network=$VPC_NAME \
    --range=10.10.10.0/24 \
    --stack-type=IPV4_ONLY

echo -e "${CYAN}Creating Subnet B: $SUBNET_B...${RESET}"
gcloud compute networks subnets create $SUBNET_B \
    --project=$PROJECT_ID \
    --region=$REGION_2 \
    --network=$VPC_NAME \
    --range=10.10.20.0/24 \
    --stack-type=IPV4_ONLY

echo -e "${CYAN}Creating Firewall Rule 1 (SSH)...${RESET}"
gcloud compute firewall-rules create $FW_1 \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=0.0.0.0/0

echo -e "${CYAN}Creating Firewall Rule 2 (RDP)...${RESET}"
gcloud compute firewall-rules create $FW_2 \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --priority=65535 \
    --action=ALLOW \
    --rules=tcp:3389 \
    --source-ranges=0.0.0.0/24

echo -e "${CYAN}Creating Firewall Rule 3 (ICMP)...${RESET}"
gcloud compute firewall-rules create $FW_3 \
    --project=$PROJECT_ID \
    --network=$VPC_NAME \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --rules=icmp \
    --source-ranges=10.10.10.0/24,10.10.20.0/24

echo -e "${CYAN}Creating VM: us-test-01...${RESET}"
gcloud compute instances create us-test-01 \
    --project=$PROJECT_ID \
    --zone=$ZONE_1 \
    --subnet=$SUBNET_A \
    --machine-type=e2-standard-2

echo -e "${CYAN}Creating VM: us-test-02...${RESET}"
gcloud compute instances create us-test-02 \
    --project=$PROJECT_ID \
    --zone=$ZONE_2 \
    --subnet=$SUBNET_B \
    --machine-type=e2-standard-2

echo -e "${YELLOW}Waiting 20 seconds for VMs to fully boot before ping test...${RESET}"
sleep 20

INTERNAL_IP=$(gcloud compute instances describe us-test-02 --zone=$ZONE_2 --format='get(networkInterfaces[0].networkIP)')
echo -e "${CYAN}Running Ping Test from us-test-01 to us-test-02...${RESET}"
gcloud compute ssh us-test-01 \
    --zone=$ZONE_1 \
    --project=$PROJECT_ID \
    --quiet \
    --command="ping -c 3 $INTERNAL_IP && ping -c 3 us-test-02.$ZONE_2.c.$PROJECT_ID.internal"

MAGENTA='\e[1;35m'
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"

# Subscribe to Orbit of Ops https://www.youtube.com/@orbitofops/videos
