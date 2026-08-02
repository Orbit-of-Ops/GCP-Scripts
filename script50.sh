#!/bin/bash

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
echo -e "${MAGENTA}${BOLD} 🚀 Starting Orbit of Ops Master Execution (GSP315)... ${RESET}"
echo -e "${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# PRE-FLIGHT CHECKS & VARIABLES (DYNAMIC AUTO-FETCH)
# ==============================================================================
echo -e "${BOLD}${YELLOW}[Orbit of Ops] Auto-fetching Project Configuration...${RESET}"

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
# USER INPUT
# ==============================================================================
echo -e "${BOLD}${YELLOW}⚠️ ATTENTION: Check your lab instructions for the following values: ${RESET}"

echo -ne "${BOLD}${CYAN}Enter the Bucket Name (from Task 1): ${RESET}"
read BUCKET_NAME

echo -ne "${BOLD}${CYAN}Enter the Pub/Sub Topic Name (from Task 2): ${RESET}"
read TOPIC_NAME

echo -ne "${BOLD}${CYAN}Enter the Cloud Run Function Name (from Task 3): ${RESET}"
read FUNCTION_NAME

echo -ne "${BOLD}${CYAN}Enter Username 2 (The user to be removed from Task 4): ${RESET}"
read USERNAME_2

echo -e "\n${BLUE}--------------------------------------------------------------------------------${RESET}\n"

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

echo -e "${BOLD}${CYAN}[Orbit of Ops] Enabling required APIs...${RESET}"
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Configuring necessary IAM permissions...${RESET}"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
    --role=roles/eventarc.eventReceiver --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
    --role=roles/pubsub.publisher --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com \
    --role=roles/eventarc.serviceAgent --quiet

SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p $PROJECT_ID)"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role='roles/pubsub.publisher' --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:service-$PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com \
    --role=roles/iam.serviceAccountTokenCreator --quiet

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 1: Creating bucket '$BUCKET_NAME'...${RESET}"
# Ignore error if bucket already exists from previous run
gsutil mb -l $REGION gs://$BUCKET_NAME 2>/dev/null || true

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 2: Creating Pub/Sub topic '$TOPIC_NAME'...${RESET}"
# Ignore error if topic already exists
gcloud pubsub topics create $TOPIC_NAME 2>/dev/null || true

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Writing Node.js payload...${RESET}"
mkdir -p ~/cloud-function-code
cd ~/cloud-function-code

cat > index.js <<EOF
const functions = require('@google-cloud/functions-framework');const { Storage } = require('@google-cloud/storage');const { PubSub } = require('@google-cloud/pubsub');const sharp = require('sharp');

functions.cloudEvent('$FUNCTION_NAME', async cloudEvent => {
  const event = cloudEvent.data;

  console.log(\`Event: \${JSON.stringify(event)}\`);
  console.log(\`Hello \${event.bucket}\`);

  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = new Storage().bucket(bucketName);
  const topicName = "$TOPIC_NAME";
  const pubsub = new PubSub();

  if (fileName.search("64x64_thumbnail") === -1) {
    const filename_split = fileName.split('.');
    const filename_ext = filename_split[filename_split.length - 1].toLowerCase();
    const filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length - 1); 

    if (filename_ext === 'png' || filename_ext === 'jpg' || filename_ext === 'jpeg') {
      console.log(\`Processing Original: gs://\${bucketName}/\${fileName}\`);
      const gcsObject = bucket.file(fileName);
      const newFilename = \`\${filename_without_ext}_64x64_thumbnail.\${filename_ext}\`;
      const gcsNewObject = bucket.file(newFilename);

      try {
        const [buffer] = await gcsObject.download();
        const resizedBuffer = await sharp(buffer)
          .resize(64, 64, {
            fit: 'inside',
            withoutEnlargement: true,
          })
          .toFormat(filename_ext)
          .toBuffer();

        await gcsNewObject.save(resizedBuffer, {
          metadata: {
            contentType: \`image/\${filename_ext}\`,
          },
        });

        console.log(\`Success: \${fileName} → \${newFilename}\`);

        await pubsub
          .topic(topicName)
          .publishMessage({ data: Buffer.from(newFilename) });

        console.log(\`Message published to \${topicName}\`);
      } catch (err) {
        console.error(\`Error: \${err}\`);
      }
    } else {
      console.log(\`gs://\${bucketName}/\${fileName} is not an image I can handle\`);
    }
  } else {
    console.log(\`gs://\${bucketName}/\${fileName} already has a thumbnail\`);
  }
});
EOF

cat > package.json <<EOF
{
 "name": "thumbnails",
 "version": "1.0.0",
 "description": "Create Thumbnail of uploaded image",
 "scripts": {
   "start": "node index.js"
 },
 "dependencies": {
   "@google-cloud/functions-framework": "^3.0.0",
   "@google-cloud/pubsub": "^2.0.0",
   "@google-cloud/storage": "^6.11.0",
   "sharp": "^0.32.1"
 },
 "devDependencies": {},
 "engines": {
   "node": ">=4.3.2"
 }
}
EOF

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Deploying Gen 2 Cloud Function...${RESET}"
echo -e "${YELLOW}Note: If Eventarc permissions are still propagating, this step will auto-retry until successful.${RESET}"

MAX_RETRIES=4
RETRY_COUNT=0
DEPLOY_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if gcloud functions deploy $FUNCTION_NAME \
      --gen2 \
      --runtime nodejs22 \
      --trigger-resource $BUCKET_NAME \
      --trigger-event google.storage.object.finalize \
      --entry-point $FUNCTION_NAME \
      --region=$REGION \
      --source . \
      --quiet; then
    DEPLOY_SUCCESS=true
    break
  else
    echo -e "${RED}⚠️ Eventarc permissions propagating. Retrying in 30 seconds... ($((RETRY_COUNT+1))/$MAX_RETRIES)${RESET}"
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT+1))
  fi
done

if [ "$DEPLOY_SUCCESS" = false ]; then
  echo -e "${RED}❌ Deployment failed after $MAX_RETRIES attempts. Please check Cloud Shell for details.${RESET}"
  exit 1
fi

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 3: Uploading test image to trigger function...${RESET}"
curl -s -o map.jpg https://storage.googleapis.com/cloud-training/gsp315/map.jpg
gsutil cp map.jpg gs://$BUCKET_NAME/map.jpg

echo -e "\n${BOLD}${CYAN}[Orbit of Ops] Task 4: Removing Username 2 ($USERNAME_2) from project...${RESET}"
gcloud projects remove-iam-policy-binding $PROJECT_ID \
    --member=user:$USERNAME_2 \
    --role=roles/viewer --quiet

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
echo -e "${GREEN}${BOLD}You can now safely click ALL 'Check my progress' buttons in your lab manual.${RESET}"
echo -e "${CYAN}${BOLD}Subscribe to Orbit of Ops: https://www.youtube.com/@orbitofops/videos${RESET}\n"
