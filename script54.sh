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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (ARC111)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project, Region, and Account...${RESET}"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export REGION=$(gcloud config get-value compute/region 2>/dev/null)
export USER_EMAIL=$(gcloud config get-value account 2>/dev/null)

if [[ -z "$REGION" ]]; then
    echo -e "${BOLD}${RED}⚠️ Region not set in gcloud config.${RESET}"
    echo -ne "${BOLD}${CYAN}Please enter the lab Region (e.g., us-east1): ${RESET}"
    read REGION
    gcloud config set compute/region $REGION 2>/dev/null
fi

echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}"
echo -e "✅ Account:    ${GREEN}$USER_EMAIL${RESET}\n"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# USER INPUT
# ==============================================================================
echo -e "${BOLD}${YELLOW}⚠️ ATTENTION: Check your lab instructions for the following values: ${RESET}"

echo -ne "${BOLD}${CYAN}Enter Bucket 1 Name: ${RESET}"
read BUCKET_1

echo -ne "${BOLD}${CYAN}Enter Bucket 2 Name: ${RESET}"
read BUCKET_2

echo -ne "${BOLD}${CYAN}Enter Bucket 3 Name: ${RESET}"
read BUCKET_3

echo -ne "\n${BOLD}${MAGENTA}Enter your assigned Form ID (1, 2, or 3): ${RESET}"
read FORM_ID

echo -e "\n${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION (DYNAMIC ROUTING)
# ==============================================================================

if [ "$FORM_ID" == "1" ]; then
    echo -e "${BOLD}${CYAN}[Orbit of Ops] Executing tasks for Form 1...${RESET}"
    
    echo -e "${YELLOW}Creating Bucket 1...${RESET}"
    gsutil mb -l $REGION gs://$BUCKET_1
    
    echo -e "${YELLOW}Setting 30s retention policy on Bucket 2...${RESET}"
    gsutil retention set 30s gs://$BUCKET_2
    
    echo -e "${YELLOW}Creating sample file and copying to Bucket 3...${RESET}"
    echo "Cloud Storage Demo" > sample.txt
    gsutil cp sample.txt gs://$BUCKET_3/

elif [ "$FORM_ID" == "2" ]; then
    echo -e "${BOLD}${CYAN}[Orbit of Ops] Executing tasks for Form 2...${RESET}"
    
    echo -e "${YELLOW}Creating Bucket 1 (Nearline)...${RESET}"
    gsutil mb -c nearline -l $REGION gs://$BUCKET_1
    
    echo -e "${YELLOW}Disabling uniform bucket-level access on Bucket 2...${RESET}"
    gcloud storage buckets update gs://$BUCKET_2 --no-uniform-bucket-level-access
    
    echo -e "${YELLOW}Assigning OWNER ACL to your email for Bucket 2...${RESET}"
    gsutil acl ch -u $USER_EMAIL:OWNER gs://$BUCKET_2
    
    echo -e "${YELLOW}Creating sample file and copying to Bucket 2...${RESET}"
    echo "Cloud Storage Demo" > sample.txt
    gsutil cp sample.txt gs://$BUCKET_2/
    
    echo -e "${YELLOW}Making sample file publically readable...${RESET}"
    gsutil acl ch -u allUsers:R gs://$BUCKET_2/sample.txt
    
    echo -e "${YELLOW}Updating labels on Bucket 3...${RESET}"
    gcloud storage buckets update gs://$BUCKET_3 --update-labels=key=value

elif [ "$FORM_ID" == "3" ]; then
    echo -e "${BOLD}${CYAN}[Orbit of Ops] Executing tasks for Form 3...${RESET}"
    
    echo -e "${YELLOW}Creating Bucket 1 (Nearline)...${RESET}"
    gsutil mb -c nearline -l $REGION gs://$BUCKET_1
    
    echo -e "${YELLOW}Creating sample file with specific content and copying to Bucket 2...${RESET}"
    echo "This is an example of editing the file content for cloud storage object" > sample.txt
    gsutil cp sample.txt gs://$BUCKET_2/
    
    echo -e "${YELLOW}Setting default storage class to ARCHIVE for Bucket 3...${RESET}"
    gsutil defstorageclass set ARCHIVE gs://$BUCKET_3

else
    echo -e "${BOLD}${RED}❌ Invalid Form ID entered. Please run the script again and enter 1, 2, or 3.${RESET}"
    exit 1
fi

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
