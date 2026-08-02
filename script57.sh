clear
CYAN='\e[1;36m'
BLUE='\e[1;34m'
YELLOW='\e[1;33m'
GREEN='\e[1;32m'
MAGENTA='\e[1;35m'
RED='\e[1;31m'
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
echo -e "${BLUE}${BOLD}║   🚀 BROUGHT TO YOU BY ORBIT OF OPS — MASTER SCRIPT        ║${RESET}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}\n"

# PRE-FLIGHT CHECKS & AUTO-FETCH
# ==============================================================================
echo -e "${YELLOW}${BOLD}[Orbit of Ops] Auto-fetching Project and Region...${RESET}"
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    export PROJECT_ID=$DEVSHELL_PROJECT_ID
fi
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)' 2>/dev/null)

export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null | tail -n 1)
if [[ -n "$ZONE" ]]; then
    export REGION=${ZONE%-*}
else
    echo -e "${YELLOW}${BOLD}⚠️ Could not auto-detect the region.${RESET}"
    read -p "Enter the lab REGION (e.g., us-east1): " REGION
    export REGION
fi
echo -e "✅ Project ID: ${GREEN}$PROJECT_ID${RESET}"
echo -e "✅ Region:     ${GREEN}$REGION${RESET}\n"

# LAB VARIABLES PROMPT
# ==============================================================================
echo -e "${YELLOW}${BOLD}Please enter the variables exactly as they appear in your lab panel:${RESET}"
read -p "Bucket Name: " BUCKET_NAME
export BUCKET_NAME
read -p "Pub/Sub Topic Name: " TOPIC_NAME
export TOPIC_NAME
read -p "Cloud Run Function Name: " FUNCTION_NAME
export FUNCTION_NAME

# TASK 0: ENABLE APIS & IAM PATCHES
# ==============================================================================
echo -e "\n${CYAN}0️⃣ Enabling APIs & Applying Required Eventarc IAM Patches...${RESET}"
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  run.googleapis.com \
  pubsub.googleapis.com \
  storage.googleapis.com

# Grant Pub/Sub Publisher to GCS Service Account (Required for Eventarc)
GCS_SA=$(gsutil kms serviceaccount -p $PROJECT_NUMBER 2>/dev/null)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GCS_SA}" \
  --role="roles/pubsub.publisher" \
  --quiet >/dev/null 2>&1

# Grant roles to Compute Default Service Account to prevent Code 13 & Eventarc errors
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/eventarc.eventReceiver" \
  --quiet >/dev/null 2>&1
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/artifactregistry.reader" \
  --quiet >/dev/null 2>&1

# TASK 1 & 2: CREATE BUCKET AND TOPIC
# ==============================================================================
echo -e "\n${CYAN}1️⃣ Task 1 — Creating the Storage Bucket...${RESET}"
gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION

echo -e "\n${CYAN}2️⃣ Task 2 — Creating the Pub/Sub Topic...${RESET}"
gcloud pubsub topics create $TOPIC_NAME

# TASK 3: CREATE & DEPLOY CLOUD RUN FUNCTION
# ==============================================================================
echo -e "\n${CYAN}3️⃣ Task 3 — Creating & Deploying the Thumbnail Cloud Run Function...${RESET}"
mkdir -p thumbnail_app
cd thumbnail_app

cat > index.js <<EOF
const functions = require('@google-cloud/functions-framework');
const { Storage } = require('@google-cloud/storage');
const { PubSub } = require('@google-cloud/pubsub');
const sharp = require('sharp');

functions.cloudEvent('${FUNCTION_NAME}', async cloudEvent => {
  const event = cloudEvent.data;

  console.log(\`Event: \${JSON.stringify(event)}\`);
  console.log(\`Hello \${event.bucket}\`);

  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64";
  const bucket = new Storage().bucket(bucketName);
  const topicName = "${TOPIC_NAME}";
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

echo -e "${YELLOW}Deploying Cloud Run Function (Using smart-retry logic for IAM)...${RESET}"
MAX_RETRIES=3
ATTEMPT=1
SUCCESS=false

while [ $ATTEMPT -le $MAX_RETRIES ]; do
    echo -e "${CYAN}Deployment Attempt $ATTEMPT of $MAX_RETRIES...${RESET}"
    if gcloud functions deploy $FUNCTION_NAME \
        --gen2 \
        --runtime=nodejs22 \
        --region=$REGION \
        --source=. \
        --entry-point=$FUNCTION_NAME \
        --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
        --trigger-event-filters="bucket=$BUCKET_NAME" \
        --quiet; then
        
        SUCCESS=true
        echo -e "${GREEN}✅ Function deployed successfully!${RESET}"
        break
    else
        echo -e "${RED}⚠️ Deployment failed due to IAM propagation delay.${RESET}"
        if [ $ATTEMPT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}Waiting 45 seconds for Qwiklabs backend to catch up before retrying...${RESET}"
            sleep 45
        fi
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ "$SUCCESS" = false ]; then
    echo -e "${RED}❌ Failed to deploy after $MAX_RETRIES attempts. Please check terminal logs.${RESET}"
    exit 1
fi

# TASK 4: TEST INFRASTRUCTURE
# ==============================================================================
echo -e "\n${CYAN}4️⃣ Task 4 — Testing the Infrastructure...${RESET}"
echo -e "${YELLOW}Downloading sample image and uploading to Bucket...${RESET}"
wget -q https://storage.googleapis.com/cloud-training/arc101/travel.jpg
gcloud storage cp travel.jpg gs://$BUCKET_NAME/

echo -e "${CYAN}Waiting 15 seconds for Eventarc to trigger the function and generate the thumbnail...${RESET}"
sleep 15
echo -e "${GREEN}Listing bucket contents to verify thumbnail creation:${RESET}"
gcloud storage ls gs://$BUCKET_NAME/

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
