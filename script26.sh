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

# Gather Users
PRIMARY_USER=$(gcloud config get-value account)
read -p "Please enter the Secondary User (Cymbal Security Lead) Email from the lab panel: " SECONDARY_USER

echo "1️⃣ Enabling PAM API and configuring Service Agent..."
gcloud services enable privilegedaccessmanager.googleapis.com
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
PAM_SA="service-${PROJECT_NUMBER}@gcp-sa-pam.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${PAM_SA}" --role="roles/privilegedaccessmanager.serviceAgent"

echo "2️⃣ Creating Entitlement Configuration (10 hours)..."
cat << EOF > pam-entitlement.yaml
maxRequestDuration: 36000s
eligibleUsers:
- principals:
  - user:${PRIMARY_USER}
approvalWorkflow:
  manualApprovals:
    steps:
    - approvers:
      - principals:
        - user:${SECONDARY_USER}
      approvalsNeeded: 1
privilegedAccess:
  gcpIamAccess:
    roleBindings:
    - role: roles/compute.admin
EOF

gcloud pam entitlements create pam-entitlement --project=$PROJECT_ID --location=global --entitlement-file=pam-entitlement.yaml

echo "3️⃣ Updating Entitlement Configuration (4 hours)..."
cat << EOF > pam-entitlement-update.yaml
maxRequestDuration: 14400s
eligibleUsers:
- principals:
  - user:${PRIMARY_USER}
approvalWorkflow:
  manualApprovals:
    steps:
    - approvers:
      - principals:
        - user:${SECONDARY_USER}
      approvalsNeeded: 1
privilegedAccess:
  gcpIamAccess:
    roleBindings:
    - role: roles/compute.admin
EOF

gcloud pam entitlements update pam-entitlement --project=$PROJECT_ID --location=global --entitlement-file=pam-entitlement-update.yaml

echo "=========================================================================="
echo "⚠️ MANUAL STEPS REQUIRED FOR DUAL-CONTROL WORKFLOW ⚠️"
echo "1. In your current window (Primary User), go to PAM -> My Entitlements and request a grant for 4 hours."
echo "2. Open an Incognito Window, sign in as the Secondary User, and APPROVE the request."
echo "3. As the Secondary User, REVOKE the grant."
echo "=========================================================================="
read -p "Press Enter ONLY when you have completed the manual Approve/Revoke steps in the UI..."

echo "4️⃣ Deleting the Entitlement..."
gcloud pam entitlements delete pam-entitlement --project=$PROJECT_ID --location=global --quiet

MAGENTA='\e[1;35m'
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"

# Subscribe to Orbit of Ops https://www.youtube.com/@orbitofops/videos
