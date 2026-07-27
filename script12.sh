#!/bin/bash
# ==============================================================================
# Color Variables & Branding
# ==============================================================================
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
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
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC120 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

# ==============================================================================
# Auto-Fetching Variables
# ==============================================================================
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo -e "${YELLOW}${BOLD}[*] Project ID: ${PROJECT_ID}${RESET}"

echo -e "${CYAN}${BOLD}[*] Auto-fetching assigned Lab Zone...${RESET}"
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)

if [ -z "$ZONE" ]; then
    export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
fi

if [ -z "$ZONE" ]; then
    echo -e "\n${RED}${BOLD}[!] Auto-fetch blocked by Qwiklabs. Please manually copy your assigned Zone from the lab instructions.${RESET}"
    read -p "Enter Zone (e.g., us-east4-b): " ZONE
else
    echo -e "${GREEN}${BOLD}[*] Zone successfully identified: ${ZONE}${RESET}\n"
fi

# ==============================================================================
# Execution Steps
# ==============================================================================
echo -e "${BLUE}${BOLD}[Orbit of Ops] Task 1: Creating Cloud Storage Bucket...${RESET}"
gsutil mb -l us gs://$PROJECT_ID-bucket 2>/dev/null

echo -e "${CYAN}${BOLD}[Orbit of Ops] Task 2: Securing HTTP Firewall Rule...${RESET}"
gcloud compute firewall-rules create default-allow-http --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=http-server --quiet 2>/dev/null || true

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Task 2: Provisioning 'my-instance' VM...${RESET}"
gcloud compute instances create my-instance \
    --machine-type=e2-medium \
    --zone=$ZONE \
    --image-project=debian-cloud \
    --image-family=debian-11 \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-balanced \
    --tags=http-server \
    --quiet

echo -e "${MAGENTA}${BOLD}[Orbit of Ops] Task 2: Creating 200GB Persistent Disk...${RESET}"
gcloud compute disks create mydisk \
    --size=200GB \
    --zone=$ZONE \
    --quiet

echo -e "${BLUE}${BOLD}[Orbit of Ops] Task 2: Attaching Persistent Disk to VM...${RESET}"
gcloud compute instances attach-disk my-instance \
    --disk=mydisk \
    --zone=$ZONE \
    --quiet

echo -e "${CYAN}${BOLD}[Orbit of Ops] Waiting 30 seconds for VM SSH keys to propagate...${RESET}"
sleep 30

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Task 3: Compiling NGINX Install Payload...${RESET}"
cat > prepare_disk.sh <<'EOF_END'
#!/bin/bash
sudo apt-get update
sudo apt-get install nginx -y
sudo systemctl start nginx
EOF_END

echo -e "${MAGENTA}${BOLD}[Orbit of Ops] Task 3: Tunneling into VM and Installing NGINX...${RESET}"
gcloud compute scp prepare_disk.sh my-instance:/tmp --zone=$ZONE --quiet
gcloud compute ssh my-instance --zone=$ZONE --quiet --command="bash /tmp/prepare_disk.sh"

# ==============================================================================
# Cleanup & Completion
# ==============================================================================
rm prepare_disk.sh 2>/dev/null

echo -e "\n${GREEN}${BOLD}🎉 Congratulations For Completing The Lab !!!${RESET}"
echo -e "${GREEN}${BOLD}>>> MISSION COMPLETE! Check all progress bars in Qwiklabs. <<<${RESET}"
