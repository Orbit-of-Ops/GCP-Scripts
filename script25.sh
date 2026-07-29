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

echo "Detecting region from existing VPN tunnels..."
export REGION=$(gcloud compute vpn-tunnels list --format="value(region)" --limit=1)

if [[ -z "$REGION" ]]; then
  echo "Unable to detect region from VPN tunnels."
  exit 1
fi

echo "Region detected: $REGION"
gcloud config set compute/region $REGION

HUB_NAME=ncc-hub

# Create NCC Hub (location global)
if gcloud network-connectivity hubs describe $HUB_NAME --project=$PROJECT_ID >/dev/null 2>&1; then
  echo "Hub $HUB_NAME already exists, skipping creation."
else
  echo "Creating NCC hub $HUB_NAME..."
  gcloud network-connectivity hubs create $HUB_NAME \
    --project=$PROJECT_ID \
    --description="Global NCC Hub"
fi

# Gather VPN tunnels for On-Prem Offices
OFFICE1_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office1'" --format="value(name)")
OFFICE2_TUNNELS=$(gcloud compute vpn-tunnels list --filter="name~'office2'" --format="value(name)")

if [[ -z "$OFFICE1_TUNNELS" ]]; then
  echo "No Office 1 VPN tunnels found!"
  exit 1
fi

if [[ -z "$OFFICE2_TUNNELS" ]]; then
  echo "No Office 2 VPN tunnels found!"
  exit 1
fi

# Task 1: Connect two On-Prem VPCs using NCC (VPN spokes)
echo "Creating spokes for On-Prem Office 1 VPN tunnels..."
i=1
while read -r tunnel_name; do
  tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
  spoke_name="office-1-spoke-$i"
  echo "Creating spoke $spoke_name for tunnel $tunnel_name"

  gcloud alpha network-connectivity spokes create $spoke_name \
    --project=$PROJECT_ID \
    --hub=$HUB_NAME \
    --region=$REGION \
    --vpn-tunnel=$tunnel_full \
    --description="Spoke for On-Prem Office 1 tunnel $i" || echo "⚠️ $spoke_name may already exist."

  ((i++))
done <<< "$OFFICE1_TUNNELS"

echo "Creating spokes for On-Prem Office 2 VPN tunnels..."
i=1
while read -r tunnel_name; do
  tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
  spoke_name="office-2-spoke-$i"
  echo "Creating spoke $spoke_name for tunnel $tunnel_name"

  gcloud alpha network-connectivity spokes create $spoke_name \
    --project=$PROJECT_ID \
    --hub=$HUB_NAME \
    --region=$REGION \
    --vpn-tunnel=$tunnel_full \
    --description="Spoke for On-Prem Office 2 tunnel $i" || echo "⚠️ $spoke_name may already exist."

  ((i++))
done <<< "$OFFICE2_TUNNELS"

WORKLOAD_VPC1="workload-vpc-1"
WORKLOAD_VPC2="workload-vpc-2"

echo "Creating workload VPC spokes..."
gcloud network-connectivity spokes linked-vpc-network create workload-1-spoke \
  --project=$PROJECT_ID \
  --hub=$HUB_NAME \
  --vpc-network=$WORKLOAD_VPC1 \
  --global \
  --description="Spoke for Workload VPC 1" || echo "⚠️ workload-1-spoke may already exist."

gcloud network-connectivity spokes linked-vpc-network create workload-2-spoke \
  --project=$PROJECT_ID \
  --hub=$HUB_NAME \
  --vpc-network=$WORKLOAD_VPC2 \
  --global \
  --description="Spoke for Workload VPC 2" || echo "⚠️ workload-2-spoke may already exist."

echo "Creating hybrid spokes for On-Prem Office 1 VPN tunnels..."
i=1
while read -r tunnel_name; do
  tunnel_full="projects/$PROJECT_ID/regions/$REGION/vpnTunnels/$tunnel_name"
  spoke_name="hybrid-office-1-spoke-$i"
  echo "Creating hybrid spoke $spoke_name for tunnel $tunnel_name"

  gcloud alpha network-connectivity spokes create $spoke_name \
    --project=$PROJECT_ID \
    --hub=$HUB_NAME \
    --region=$REGION \
    --vpn-tunnel=$tunnel_full \
    --description="Hybrid spoke for On-Prem Office 1 tunnel $i" || echo "⚠️ $spoke_name may already exist."

  ((i++))
done <<< "$OFFICE1_TUNNELS"

MAGENTA='\e[1;35m'
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"

# Subscribe to Orbit of Ops https://www.youtube.com/@orbitofops/videos
