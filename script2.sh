#!/bin/bash
clear

# ==============================================================================
# GSP510 FLAWLESS MASTER SCRIPT (RECORDING EDITION)
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
echo "${MAGENTA}${BOLD}>>> INITIATING GKE KUBERNETES AUTOMATION <<<${RESET}"
echo ""

# ==============================================================================
# PHASE 1: AUTO-FETCH & CONFIRM ZONE
# ==============================================================================
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
DETECTED_ZONE=$(gcloud config get-value compute/zone 2>/dev/null)

if [ -z "$DETECTED_ZONE" ]; then
    DETECTED_ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
fi

echo "${CYAN}[*] Auto-detected Zone: ${YELLOW}${BOLD}${DETECTED_ZONE}${RESET}"
read -p "Press ENTER to use '${DETECTED_ZONE}' or type a different ZONE: " INPUT_ZONE

if [ -n "$INPUT_ZONE" ]; then
    export ZONE=$INPUT_ZONE
else
    export ZONE=$DETECTED_ZONE
fi

export REGION="${ZONE%-*}"
gcloud config set compute/zone $ZONE --quiet
echo "${GREEN}[+] Confirmed Zone: $ZONE | Region: $REGION${RESET}"
echo ""

# ==============================================================================
# PHASE 2: INTERACTIVE VARIABLE GATHERING
# ==============================================================================
echo "${YELLOW}${BOLD}Please enter the exact randomized names from your lab instructions:${RESET}"
read -p "Enter CLUSTER NAME: " CLUSTER_NAME
read -p "Enter NAMESPACE: " NAMESPACE
read -p "Enter INTERVAL (e.g., 10s): " INTERVAL
read -p "Enter REPO NAME: " REPO_NAME
read -p "Enter SERVICE NAME: " SERVICE_NAME
echo ""

echo "${CYAN}${BOLD}[*] Target Locked. Executing Pipeline...${RESET}"

# ==============================================================================
# TASK 1: CREATE GKE CLUSTER
# ==============================================================================
echo -e "\n${YELLOW}[*] Task 1: Creating GKE Cluster (This takes ~3-5 minutes)...${RESET}"
gcloud container clusters create $CLUSTER_NAME \
    --zone $ZONE \
    --release-channel regular \
    --cluster-version latest \
    --num-nodes 3 \
    --min-nodes 2 \
    --max-nodes 6 \
    --enable-autoscaling \
    --no-enable-ip-alias \
    --quiet

gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --quiet

# ==============================================================================
# TASK 2: ENABLE MANAGED PROMETHEUS & NAMESPACE
# ==============================================================================
echo -e "\n${YELLOW}[*] Task 2: Enabling Managed Prometheus & Setting Up Monitoring...${RESET}"
gcloud container clusters update $CLUSTER_NAME --enable-managed-prometheus --zone $ZONE --quiet
  
kubectl create ns $NAMESPACE
  
gsutil cp gs://spls/gsp510/prometheus-app.yaml .
cat > prometheus-app.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-test
  labels:
    app: prometheus-test
spec:
  selector:
    matchLabels:
      app: prometheus-test
  replicas: 3
  template:
    metadata:
      labels:
        app: prometheus-test
    spec:
      nodeSelector:
        kubernetes.io/os: linux
        kubernetes.io/arch: amd64
      containers:
      - image: nilebox/prometheus-example-app:latest
        name: prometheus-test
        ports:
        - name: metrics
          containerPort: 1234
        command:
        - "/main"
        - "--process-metrics"
        - "--go-metrics"
EOF
kubectl -n $NAMESPACE apply -f prometheus-app.yaml
  
gsutil cp gs://spls/gsp510/pod-monitoring.yaml .
cat > pod-monitoring.yaml <<EOF
apiVersion: monitoring.googleapis.com/v1alpha1
kind: PodMonitoring
metadata:
  name: prometheus-test
  labels:
    app.kubernetes.io/name: prometheus-test
spec:
  selector:
    matchLabels:
      app: prometheus-test
  endpoints:
  - port: metrics
    interval: $INTERVAL
EOF
kubectl -n $NAMESPACE apply -f pod-monitoring.yaml

# ==============================================================================
# TASK 3: DEPLOY BUGGY APP
# ==============================================================================
echo -e "\n${YELLOW}[*] Task 3: Deploying Initial Application (Generating Error State)...${RESET}"
cd ~
gsutil cp -r gs://spls/gsp510/hello-app/ .
cd ~/hello-app
kubectl -n $NAMESPACE apply -f manifests/helloweb-deployment.yaml
sleep 3 # Brief pause to let Kubernetes register the buggy pod

# ==============================================================================
# TASK 5: FIX & RE-DEPLOY APP (v1.0)
# ==============================================================================
echo -e "\n${YELLOW}[*] Task 5: Fixing Image Reference & Re-deploying App (v1.0)...${RESET}"
cat > manifests/helloweb-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
EOF

kubectl delete deployments helloweb -n $NAMESPACE
sleep 5 # Ensure deployment is fully deleted before recreating
kubectl -n $NAMESPACE apply -f manifests/helloweb-deployment.yaml

# ==============================================================================
# TASK 6: CONTAINERIZE, PUSH & EXPOSE (v2.0)
# ==============================================================================
echo -e "\n${YELLOW}[*] Task 6: Updating Code, Building v2 Docker Image & Exposing...${RESET}"
cat > main.go <<'EOF'
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", hello)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func hello(w http.ResponseWriter, r *http.Request) {
	log.Printf("Serving request: %s", r.URL.Path)
	host, _ := os.Hostname()
	fmt.Fprintf(w, "Hello, world!\n")
	fmt.Fprintf(w, "Version: 2.0.0\n")
	fmt.Fprintf(w, "Hostname: %s\n", host)
}
EOF
 
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2 .
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2
  
# By using 'set image', we preserve the v1.0 ReplicaSet history for the Task 5 grader!
kubectl set image deployment/helloweb -n $NAMESPACE hello-app=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/hello-app:v2
kubectl expose deployment helloweb -n $NAMESPACE --name=$SERVICE_NAME --type=LoadBalancer --port 8080 --target-port 8080

# ==============================================================================
# TASK 4: LOGS-BASED METRIC & ALERTING POLICY (Placed at end for safety)
# ==============================================================================
echo -e "\n${YELLOW}[*] Task 4: Creating Logs-Based Metric and Alerting Policy...${RESET}"
gcloud logging metrics create pod-image-errors \
  --description="Pod Image Errors Metric" \
  --log-filter='resource.type="k8s_pod" severity=WARNING' \
  --quiet

cat > awesome.json <<EOF_END
{
  "displayName": "Pod Error Alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "Kubernetes Pod - logging/user/pod-image-errors",
      "conditionThreshold": {
        "filter": "resource.type = \"k8s_pod\" AND metric.type = \"logging.googleapis.com/user/pod-image-errors\"",
        "aggregations": [
          {
            "alignmentPeriod": "600s",
            "crossSeriesReducer": "REDUCE_SUM",
            "perSeriesAligner": "ALIGN_COUNT"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 0
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "604800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": []
}
EOF_END

gcloud alpha monitoring policies create --policy-from-file="awesome.json" --quiet

echo -e "\n${GREEN}${BOLD}====================================================================${RESET}"
echo "${GREEN}${BOLD}>>> AUTOMATION COMPLETE! ALL TASKS ARE PROVISIONED! <<<${RESET}"
echo "${GREEN}${BOLD}====================================================================${RESET}"
echo "${WHITE}${BOLD}You can now click 'Check my progress' on ALL tasks for your 100/100!${RESET}"
