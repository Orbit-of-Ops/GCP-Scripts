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

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)' 2>/dev/null)

echo -e "${YELLOW}${BOLD}Please enter the variables exactly as they appear in your lab panel:${RESET}"
read -p "Zone (e.g., us-east4-b): " ZONE
export REGION=${ZONE%-*}
read -p "Bucket Name: " BUCKET_NAME
export BUCKET_NAME
read -p "Pub/Sub Topic Name: " TOPIC_NAME
export TOPIC_NAME
read -p "Cloud Function Name: " FUNCTION_NAME
export FUNCTION_NAME

echo -e "\n${CYAN}0️⃣ Enabling APIs & Force-Patching IAM Roles...${RESET}"
gcloud services enable artifactregistry.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com eventarc.googleapis.com run.googleapis.com pubsub.googleapis.com storage.googleapis.com

RAW_SA=$(gsutil kms serviceaccount -p $PROJECT_NUMBER)
CLEAN_SA=$(echo "$RAW_SA" | sed 's/serviceAccount://g' | tr -d '[:space:]')

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${CLEAN_SA}" --role="roles/pubsub.publisher" --quiet >/dev/null 2>&1

COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${COMPUTE_SA}" --role="roles/eventarc.eventReceiver" --quiet >/dev/null 2>&1
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${COMPUTE_SA}" --role="roles/artifactregistry.reader" --quiet >/dev/null 2>&1

PUBSUB_SA="service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${PUBSUB_SA}" --role="roles/iam.serviceAccountTokenCreator" --quiet >/dev/null 2>&1

EVENTARC_SA="service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${EVENTARC_SA}" --role="roles/eventarc.serviceAgent" --quiet >/dev/null 2>&1

echo -e "\n${CYAN}1️⃣ Task 1 — Creating Storage Bucket...${RESET}"
gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION 2>/dev/null

echo -e "\n${CYAN}2️⃣ Task 2 — Creating the Pub/Sub Topic...${RESET}"
gcloud pubsub topics create $TOPIC_NAME 2>/dev/null

echo -e "\n${CYAN}3️⃣ Task 3 — Creating & Deploying the Thumbnail Cloud Function...${RESET}"
mkdir -p ~/thumbnail_app
cd ~/thumbnail_app

cat > index.js <<EOF
/* globals exports, require */
//jshint strict: false
//jshint esversion: 6
"use strict";
const crc32 = require("fast-crc32c");
const { Storage } = require('@google-cloud/storage');
const gcs = new Storage();
const { PubSub } = require('@google-cloud/pubsub');
const imagemagick = require("imagemagick-stream");

exports.thumbnail = (event, context) => {
  const fileName = event.name;
  const bucketName = event.bucket;
  const size = "64x64"
  const bucket = gcs.bucket(bucketName);
  const topicName = "${TOPIC_NAME}";
  const pubsub = new PubSub();
  if ( fileName.search("64x64_thumbnail") == -1 ){
    var filename_split = fileName.split('.');
    var filename_ext = filename_split[filename_split.length - 1];
    var filename_without_ext = fileName.substring(0, fileName.length - filename_ext.length );
    if (filename_ext.toLowerCase() == 'png' || filename_ext.toLowerCase() == 'jpg'){
      console.log(\`Processing Original: gs://\${bucketName}/\${fileName}\`);
      const gcsObject = bucket.file(fileName);
      let newFilename = filename_without_ext + size + '_thumbnail.' + filename_ext;
      let gcsNewObject = bucket.file(newFilename);
      let srcStream = gcsObject.createReadStream();
      let dstStream = gcsNewObject.createWriteStream();
      let resize = imagemagick().resize(size).quality(90);
      srcStream.pipe(resize).pipe(dstStream);
      return new Promise((resolve, reject) => {
        dstStream
          .on("error", (err) => {
            console.log(\`Error: \${err}\`);
            reject(err);
          })
          .on("finish", () => {
            console.log(\`Success: \${fileName} → \${newFilename}\`);
              gcsNewObject.setMetadata(
              {
                contentType: 'image/'+ filename_ext.toLowerCase()
              }, function(err, apiResponse) {});
              pubsub
                .topic(topicName)
                .publisher()
                .publish(Buffer.from(newFilename))
                .then(messageId => {
                  console.log(\`Message \${messageId} published.\`);
                })
                .catch(err => {
                  console.error('ERROR:', err);
                });
          });
      });
    }
  }
};
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
    "@google-cloud/pubsub": "^2.0.0",
    "@google-cloud/storage": "^5.0.0",
    "fast-crc32c": "1.0.4",
    "imagemagick-stream": "4.1.1"
  },
  "devDependencies": {},
  "engines": {
    "node": ">=4.3.2"
  }
}
EOF

echo -e "\n${YELLOW}Waiting 45 seconds to guarantee all IAM policies have propagated...${RESET}"
sleep 45

echo -e "${YELLOW}Deploying Cloud Function (Restricted to 1 instance)...${RESET}"

DEPLOY_CMD="gcloud functions deploy $FUNCTION_NAME --gen2 --runtime=nodejs22 --region=$REGION --source=. --entry-point=thumbnail --trigger-bucket=$BUCKET_NAME --max-instances=1 --quiet"

eval $DEPLOY_CMD || { echo -e "${RED}⚠️ Attempt 1 failed (IAM delay). Waiting 45 seconds...${RESET}"; sleep 45; eval $DEPLOY_CMD; }

echo -e "\n${CYAN}4️⃣ Testing Infrastructure & Triggering Function...${RESET}"
wget -q https://storage.googleapis.com/cloud-training/arc102/wildlife.jpg
gcloud storage cp wildlife.jpg gs://$BUCKET_NAME/ 2>/dev/null

echo -e "${YELLOW}Waiting 15 seconds for processing...${RESET}"
sleep 15
gcloud storage ls gs://$BUCKET_NAME/

echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"
