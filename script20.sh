GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
RESET='\e[0m'
BOLD='\e[1m'
BLINK='\e[5m'

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
echo -e "${BLUE}${BOLD}║                                                            ║${RESET}"
echo -e "${BLUE}${BOLD}║   🌊 WELCOME TO Orbit Of Ops                               ║${RESET}"
echo -e "${BLUE}${BOLD}║   🚀 TARGET: ARC115 MONITORING CHALLENGE LAB               ║${RESET}"
echo -e "${BLUE}${BOLD}║                                                            ║${RESET}"
echo -e "${BLUE}${BOLD}║   📺 Subscribe & Learn more at:                            ║${RESET}"
echo -e "${BLUE}${BOLD}║   ${BLINK}https://youtube.com/@orbitofops${RESET}${BLUE}${BOLD}                     ║${RESET}"
echo -e "${BLUE}${BOLD}║                                                            ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# ------------------------------------------------------------------
# Initialization & VM Discovery
# ------------------------------------------------------------------
export PROJECT_ID=$(gcloud config get-value project)
export USER_EMAIL=$(gcloud config get-value account)
export INSTANCE_NAME=$(gcloud compute instances list --format="value(name)" --limit=1)
export ZONE=$(gcloud compute instances list --format="value(zone)" --limit=1)
export VM_EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo -e "${MAGENTA}${BOLD}▬▬▬▬▬▬ INSTANCE DISCOVERY ▬▬▬▬▬▬${RESET}"
echo -e "${WHITE}${BOLD} Zone:${RESET} $ZONE"
echo -e "${WHITE}${BOLD} Instance:${RESET} $INSTANCE_NAME"
echo -e "${WHITE}${BOLD} External IP:${RESET} $VM_EXTERNAL_IP\n"

# ------------------------------------------------------------------
# Task 1: Install & Configure the Modern Ops Agent
# ------------------------------------------------------------------
echo -e "${GREEN}${BOLD}▬▬▬▬▬▬ OPS AGENT DEPLOYMENT ▬▬▬▬▬▬${RESET}"
echo -e "${YELLOW}${BOLD}[*] Installing Ops Agent and routing Apache + CPU Metrics...${RESET}"

cat << 'EOF' > setup_agents.sh
#!/bin/bash
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install > /dev/null 2>&1

cat << 'YAMLEOF' | sudo tee /etc/google-cloud-ops-agent/config.yaml > /dev/null
logging:
  receivers:
    syslog:
      type: files
      include_paths:
      - /var/log/messages
      - /var/log/syslog
    apache_access:
      type: apache_access
    apache_error:
      type: apache_error
  service:
    pipelines:
      default_pipeline:
        receivers: [syslog]
      apache_pipeline:
        receivers: [apache_access, apache_error]
metrics:
  receivers:
    hostmetrics:
      type: hostmetrics
      collection_interval: 60s
    apache:
      type: apache
  service:
    pipelines:
      default_pipeline:
        receivers: [hostmetrics]
      apache_pipeline:
        receivers: [apache]
YAMLEOF

sudo systemctl restart google-cloud-ops-agent

timeout 120 bash -c -- 'while true; do curl localhost | grep -oP "<title>.*</title>"; sleep .1s;done ' > /dev/null 2>&1 &
EOF

gcloud compute scp setup_agents.sh $INSTANCE_NAME:/tmp --zone=$ZONE --quiet
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --quiet --command="bash /tmp/setup_agents.sh"

echo -e "${CYAN}${BOLD}✓ Ops Agent Active & Background Traffic Generating!${RESET}\n"

# ------------------------------------------------------------------
# Task 2: Create Uptime Check
# ------------------------------------------------------------------
echo -e "${GREEN}${BOLD}▬▬▬▬▬▬ UPTIME CHECK ▬▬▬▬▬▬${RESET}"
gcloud monitoring uptime create "Orbit of Ops Uptime" \
  --resource-type=uptime-url \
  --resource-labels=host=$VM_EXTERNAL_IP,path=/,port=80 > /dev/null 2>&1

echo -e "${CYAN}${BOLD}✓ Uptime Check Created!${RESET}\n"

# ------------------------------------------------------------------
# Task 3: Notification Channel & Alert Policy
# ------------------------------------------------------------------
echo -e "${GREEN}${BOLD}▬▬▬▬▬▬ ALERT POLICY ▬▬▬▬▬▬${RESET}"

cat > email-channel.json <<EOF
{
  "type": "email",
  "displayName": "Orbit of Ops Alert",
  "labels": {
    "email_address": "$USER_EMAIL"
  }
}
EOF

gcloud beta monitoring channels create --channel-content-from-file=email-channel.json > /dev/null 2>&1
export CHANNEL_ID=$(gcloud beta monitoring channels list --format="value(name)" --limit=1)

cat > alert-policy.json <<EOF
{
  "displayName": "Orbit of Ops Traffic Alert",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "VM Instance - Traffic",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND metric.type = \"workload.googleapis.com/apache.traffic\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_RATE"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 3072
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "1800s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$CHANNEL_ID"
  ],
  "severity": "SEVERITY_UNSPECIFIED"
}
EOF

gcloud alpha monitoring policies create --policy-from-file="alert-policy.json" > /dev/null 2>&1

echo -e "${CYAN}${BOLD}✓ Notification Channel & Alert Policy Deployed!${RESET}\n"

# ------------------------------------------------------------------
# Task 5: Log-Based Metric
# ------------------------------------------------------------------
echo -e "${GREEN}${BOLD}▬▬▬▬▬▬ LOG-BASED METRIC ▬▬▬▬▬▬${RESET}"

gcloud logging metrics create Orbit_of_Ops_Metric \
  --description="Count Apache 200 OK responses" \
  --log-filter="resource.type=\"gce_instance\" logName=\"projects/$PROJECT_ID/logs/apache-access\" textPayload:\"200\"" > /dev/null 2>&1

echo -e "${CYAN}${BOLD}✓ Log-based Metric 'Orbit_of_Ops_Metric' Created!${RESET}\n"

# Cleanup
rm setup_agents.sh email-channel.json alert-policy.json

# ------------------------------------------------------------------
# Outro
# ------------------------------------------------------------------
echo -e "${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║           🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉          ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${YELLOW}${BOLD}>>> Please follow the final UI instructions below for Task 4! <<<${RESET}"
