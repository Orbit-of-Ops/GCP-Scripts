#!/bin/bash
# ==============================================================================
# Orbit of Ops - Master Script
# Lab: GSP511 - Build Google Cloud Infrastructure for AWS Professionals
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
echo -e "${BLUE}${BOLD}║   🚀 TARGET: GSP511 AWS PROFESSIONALS CHALLENGE LAB        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching configurations...${RESET}"
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)
if [[ -z "$ZONE" ]]; then
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
# INFRASTRUCTURE PROVISIONING
# ==============================================================================
echo -e "${GREEN}${BOLD}▬▬▬▬▬▬ TASK 1 & 2: VPCs & SUBNETS ▬▬▬▬▬▬${RESET}"
gcloud compute networks create griffin-dev-vpc --subnet-mode=custom --quiet
gcloud compute networks subnets create griffin-dev-wp --network=griffin-dev-vpc --region=$REGION --range=192.168.16.0/20 --quiet
gcloud compute networks subnets create griffin-dev-mgmt --network=griffin-dev-vpc --region=$REGION --range=192.168.32.0/20 --quiet

gcloud compute networks create griffin-prod-vpc --subnet-mode=custom --quiet
gcloud compute networks subnets create griffin-prod-wp --network=griffin-prod-vpc --region=$REGION --range=192.168.48.0/20 --quiet
gcloud compute networks subnets create griffin-prod-mgmt --network=griffin-prod-vpc --region=$REGION --range=192.168.64.0/20 --quiet

echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 3: BASTION HOST ▬▬▬▬▬▬${RESET}"
gcloud compute instances create bastion \
    --zone=$ZONE \
    --machine-type=e2-medium \
    --network-interface=network=griffin-dev-vpc,subnet=griffin-dev-mgmt \
    --network-interface=network=griffin-prod-vpc,subnet=griffin-prod-mgmt \
    --tags=ssh --quiet

gcloud compute firewall-rules create fw-ssh-dev --network=griffin-dev-vpc --allow=tcp:22 --source-ranges=0.0.0.0/0 --target-tags=ssh --quiet
gcloud compute firewall-rules create fw-ssh-prod --network=griffin-prod-vpc --allow=tcp:22 --source-ranges=0.0.0.0/0 --target-tags=ssh --quiet

echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 4: CLOUD SQL (Takes ~5-7 mins) ▬▬▬▬▬▬${RESET}"
gcloud sql instances create griffin-dev-db --region=$REGION --database-version=MYSQL_5_7 --root-password="OrbitOfOpsPassword123!" --tier=db-n1-standard-1 --quiet
gcloud sql databases create wordpress --instance=griffin-dev-db --quiet
gcloud sql users create wp_user --instance=griffin-dev-db --password=stormwind_rules --quiet

echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 5: KUBERNETES CLUSTER (Takes ~5-7 mins) ▬▬▬▬▬▬${RESET}"
gcloud container clusters create griffin-dev --zone=$ZONE --machine-type=e2-standard-4 --num-nodes=2 --network=griffin-dev-vpc --subnetwork=griffin-dev-wp --quiet

# ==============================================================================
# WORKLOAD DEPLOYMENT
# ==============================================================================
echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 6: KUBERNETES SECRETS ▬▬▬▬▬▬${RESET}"
gcloud container clusters get-credentials griffin-dev --zone=$ZONE --project=$PROJECT_ID --quiet

mkdir -p ~/orbit-wp && cd ~/orbit-wp
gsutil cp -r gs://spls/gsp511/wp-k8s/* .

cat > wp-env.yaml <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: wordpress-volumeclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: database
type: Opaque
stringData:
  username: wp_user
  password: stormwind_rules
EOF

kubectl apply -f wp-env.yaml

gcloud iam service-accounts keys create key.json --iam-account=cloud-sql-proxy@$PROJECT_ID.iam.gserviceaccount.com
kubectl create secret generic cloudsql-instance-credentials --from-file key.json

echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 7: WORDPRESS DEPLOYMENT ▬▬▬▬▬▬${RESET}"
INSTANCE_CONNECTION_NAME=$(gcloud sql instances describe griffin-dev-db --format='value(connectionName)')

cat > wp-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
        - image: wordpress
          name: wordpress
          env:
          - name: WORDPRESS_DB_HOST
            value: 127.0.0.1:3306
          - name: WORDPRESS_DB_USER
            valueFrom:
              secretKeyRef:
                name: database
                key: username
          - name: WORDPRESS_DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: database
                key: password
          ports:
            - containerPort: 80
              name: wordpress
          volumeMounts:
            - name: wordpress-persistent-storage
              mountPath: /var/www/html
        - name: cloudsql-proxy
          image: gcr.io/cloudsql-docker/gce-proxy:1.33.2
          command: ["/cloud_sql_proxy",
                    "-instances=$INSTANCE_CONNECTION_NAME=tcp:3306",
                    "-credential_file=/secrets/cloudsql/key.json"]
          securityContext:
            runAsUser: 2  # non-root user
            allowPrivilegeEscalation: false
          volumeMounts:
            - name: cloudsql-instance-credentials
              mountPath: /secrets/cloudsql
              readOnly: true
      volumes:
        - name: wordpress-persistent-storage
          persistentVolumeClaim:
            claimName: wordpress-volumeclaim
        - name: cloudsql-instance-credentials
          secret:
            secretName: cloudsql-instance-credentials
EOF

kubectl apply -f wp-deployment.yaml
kubectl apply -f wp-service.yaml

echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 8: ENABLE MONITORING ▬▬▬▬▬▬${RESET}"
echo -e "${YELLOW}[*] Waiting for WordPress External IP (Takes ~60 seconds)...${RESET}"
sleep 45

EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
    EXTERNAL_IP=$(kubectl get services wordpress -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$EXTERNAL_IP" ]; then
        sleep 15
    fi
done

gcloud monitoring uptime create "Orbit of Ops WP Uptime" \
  --resource-type=uptime-url \
  --resource-labels=host=$EXTERNAL_IP,path=/,port=80 > /dev/null 2>&1

echo -e "\n${GREEN}${BOLD}▬▬▬▬▬▬ TASK 9: PROVIDE ACCESS TO ADDITIONAL ENGINEER ▬▬▬▬▬▬${RESET}"
CURRENT_USER=$(gcloud config get-value account)
USER_2=$(gcloud projects get-iam-policy $PROJECT_ID --format=json | jq -r '.bindings[] | select(.role == "roles/viewer").members[]' | grep "user:" | grep -v "$CURRENT_USER" | head -n 1)

if [[ -n "$USER_2" ]]; then
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="$USER_2" --role="roles/editor" --quiet
else
    echo -e "${MAGENTA}⚠️ Could not automatically detect the second user.${RESET}"
    read -p "$(echo -e ${BOLD}${CYAN}"Please enter 'Username 2' from the Qwiklabs panel (Email): "${RESET})" USER_2_MANUAL
    gcloud projects add-iam-policy-binding $PROJECT_ID --member="user:$USER_2_MANUAL" --role="roles/editor" --quiet
fi

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
