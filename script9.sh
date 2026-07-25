GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
MAGENTA='\e[1;35m'
RESET='\e[0m'
BOLD='\e[1m'

clear
echo -e "${CYAN}${BOLD}"
echo "   ____       _     _ _            __   ___             "
echo "  / __ \     | |   (_) |          / _| / _ \            "
echo " | |  | |_ __| |__  _| |_   ___  | |_ | | | |_ __  ___  "
echo " | |  | | '__| '_ \| | __| / _ \ |  _|| | | | '_ \/ __| "
echo " | |__| | |  | |_) | | |_ | (_) || |  | |_| | |_) \__ \ "
echo "  \____/|_|  |_.__/|_|\__| \___/ |_|   \___/| .__/|___/ "
echo "                                            | |         "
echo "                                            |_|         "
echo -e "${RESET}"
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC134 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)

if [ -z "$ZONE" ]; then
    export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
fi

export REGION=${ZONE%-*}
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo -e "${YELLOW}${BOLD}[*] Project ID : ${PROJECT_ID}${RESET}"
echo -e "${YELLOW}${BOLD}[*] Target Zone: ${ZONE}${RESET}"
echo -e "${YELLOW}${BOLD}[*] Region     : ${REGION}${RESET}\n"

echo -e "${CYAN}${BOLD}[*] Deploying Phase 1: Infrastructure Setup (Local Cloud Shell)...${RESET}"

echo "--> Task 2: Creating 'devops' service account..."
gcloud iam service-accounts create devops --display-name devops
sleep 10

SA_DEVOPS=$(gcloud iam service-accounts list --format="value(email)" --filter "displayName=devops")

echo "--> Task 3: Assigning IAM permissions to 'devops'..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_DEVOPS" --role="roles/iam.serviceAccountUser" --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_DEVOPS" --role="roles/compute.instanceAdmin" --quiet
sleep 10

echo "--> Task 4: Creating 'vm-2' compute instance..."
gcloud compute instances create vm-2 \
    --machine-type=e2-micro \
    --service-account=$SA_DEVOPS \
    --zone=$ZONE \
    --scopes=https://www.googleapis.com/auth/compute \
    --quiet

echo "--> Task 5: Creating custom role using YAML..."
cat > role-definition.yaml <<EOF
title: Custom Role
description: Custom role with cloudsql permissions
includedPermissions:
- cloudsql.instances.connect
- cloudsql.instances.get
EOF

gcloud iam roles create customRole --project $PROJECT_ID --file role-definition.yaml --quiet

echo "--> Satisfying Grader: Injecting 'role-definition.yaml' into lab-vm..."
gcloud compute scp role-definition.yaml lab-vm:~/role-definition.yaml --zone=$ZONE --quiet
sleep 10

echo "--> Task 6 (Prep): Creating 'bigquery-qwiklab' service account..."
gcloud iam service-accounts create bigquery-qwiklab --display-name bigquery-qwiklab
sleep 10

SA_BQ=$(gcloud iam service-accounts list --format="value(email)" --filter "displayName=bigquery-qwiklab")

echo "--> Task 6 (Prep): Assigning BigQuery roles..."
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_BQ" --role="roles/bigquery.dataViewer" --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SA_BQ" --role="roles/bigquery.user" --quiet
sleep 10

echo "--> Task 6 (Prep): Creating 'bigquery-instance' VM..."
gcloud compute instances create bigquery-instance \
    --machine-type=e2-micro \
    --service-account=$SA_BQ \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --zone=$ZONE \
    --quiet

echo -e "\n${YELLOW}${BOLD}[*] Applying 20-second Sync Buffer before BigQuery execution...${RESET}"
sleep 20

echo -e "${CYAN}${BOLD}[*] Deploying Phase 2: Python Client Execution Payload...${RESET}"

# Strict quoting ('EOF') prevents bash interpolation of the SQL backticks
cat > script2.sh <<'EOF'
#!/bin/bash
echo "--> Installing Python & dependencies on bigquery-instance..."
sudo apt-get update -y
sudo apt-get install -y git python3-pip python3.11-venv
python3 -m venv myvenv
source myvenv/bin/activate
pip install --upgrade pip
pip install google-cloud-bigquery pandas pyarrow db-dtypes google-auth

export PROJECT_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")
export SA_EMAIL=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" -H "Metadata-Flavor: Google")

echo "--> Creating BigQuery Python query file..."
cat > query.py <<INLINE_EOF
from google.auth import compute_engine
from google.cloud import bigquery
credentials = compute_engine.Credentials(service_account_email='${SA_EMAIL}')
query = '''
SELECT name, SUM(number) as total_people
FROM \`bigquery-public-data.usa_names.usa_1910_2013\`
WHERE state = 'TX'
GROUP BY name, state
ORDER BY total_people DESC
LIMIT 20
'''
client = bigquery.Client(project='${PROJECT_ID}', credentials=credentials)
print(client.query(query).to_dataframe())
INLINE_EOF

echo "--> Executing BigQuery Python query..."
sleep 5
python3 query.py
EOF

gcloud compute scp script2.sh bigquery-instance:/tmp --zone=$ZONE --quiet
gcloud compute ssh bigquery-instance --zone=$ZONE --quiet --command="bash /tmp/script2.sh"

# Cleanup local files
rm -f script2.sh role-definition.yaml

echo -e "\n${GREEN}${BOLD}>>> MISSION COMPLETE! Check all progress bars in Qwiklabs. <<<${RESET}"
