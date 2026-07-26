GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
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
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC132 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

echo -e "${YELLOW}${BOLD}Please enter the specific variables from your lab manual:${RESET}"
read -p "Enter API Key: " API_KEY
read -p "Enter Task 2 File Name: " task_2_file_name
read -p "Enter Task 3 Request File Name: " task_3_request_file
read -p "Enter Task 3 Response File Name: " task_3_response_file
read -p "Enter Task 4 Sentence to Translate: " task_4_sentence
read -p "Enter Task 4 Output File Name: " task_4_file
read -p "Enter Task 5 Sentence to Detect: " task_5_sentence
read -p "Enter Task 5 Output File Name: " task_5_file
echo ""

export PROJECT_ID=$(gcloud config get-value project)
export ZONE=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
if [ -z "$ZONE" ]; then
    export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
fi
export VM_NAME=$(gcloud compute instances list --format="value(name)" | head -n 1)

echo -e "${YELLOW}${BOLD}[*] Project ID: ${PROJECT_ID}${RESET}"
echo -e "${YELLOW}${BOLD}[*] Zone      : ${ZONE}${RESET}"
echo -e "${YELLOW}${BOLD}[*] Target VM : ${VM_NAME}${RESET}\n"

echo -e "${CYAN}${BOLD}[*] Compiling Remote Execution Payload...${RESET}"

cat > remote_payload.sh <<EOF
#!/bin/bash
export API_KEY="${API_KEY}"
export task_2_file_name="${task_2_file_name}"
export task_3_request_file="${task_3_request_file}"
export task_3_response_file="${task_3_response_file}"
export task_4_sentence="${task_4_sentence}"
export task_4_file="${task_4_file}"
export task_5_sentence="${task_5_sentence}"
export task_5_file="${task_5_file}"
EOF

cat >> remote_payload.sh <<'EOF_SCRIPT'
echo "--> Setting up environment..."
audio_uri="gs://cloud-samples-data/speech/corbeau_renard.flac"
export PROJECT_ID=$(gcloud config get-value project)

echo "--> Activating Python Virtual Environment..."
source venv/bin/activate

echo "--> [Task 2] Generating synthetic speech JSON..."
cat > synthesize-text.json <<EOF
{
   "input":{
      "text":"Cloud Text-to-Speech API allows developers to include natural-sounding, synthetic human speech as playable audio in their applications. The Text-to-Speech API converts text or Speech Synthesis Markup Language (SSML) input into audio data like MP3 or LINEAR16 (the encoding used in WAV files)."
   },
   "voice":{
      "languageCode":"en-gb",
      "name":"en-GB-Standard-A",
      "ssmlGender":"FEMALE"
   },
   "audioConfig":{
      "audioEncoding":"MP3"
   }
}
EOF

echo "--> [Task 2] Calling Text-to-Speech API..."
curl -s -H "Authorization: Bearer "$(gcloud auth application-default print-access-token) \
-H "Content-Type: application/json; charset=utf-8" \
-d @synthesize-text.json "https://texttospeech.googleapis.com/v1/text:synthesize" \
> $task_2_file_name

echo "--> [Task 3] Generating Speech-to-Text request JSON..."
cat > "$task_3_request_file" <<EOF
{
   "config": {
      "encoding": "FLAC",
      "sampleRateHertz": 44100,
      "languageCode": "fr-FR"
   },
   "audio": {
      "uri": "$audio_uri"
   }
}
EOF

echo "--> [Task 3] Calling Speech-to-Text API..."
curl -s -X POST -H "Content-Type: application/json" \
--data-binary @"$task_3_request_file" \
"https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" \
-o "$task_3_response_file"

echo "--> [Task 4] Calling Translation API (Translate)..."
response=$(curl -s -X POST \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json; charset=utf-8" \
-d "{\"q\": \"$task_4_sentence\"}" \
"https://translation.googleapis.com/language/translate/v2?key=${API_KEY}&source=ja&target=en")

echo "$response" > "$task_4_file"

echo "--> [Task 5] Calling Translation API (Detect)..."
curl -s -X POST \
-H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
-H "Content-Type: application/json; charset=utf-8" \
-d "{\"q\": [\"$task_5_sentence\"]}" \
"https://translation.googleapis.com/language/translate/v2/detect?key=${API_KEY}" \
-o "$task_5_file"

EOF_SCRIPT

echo -e "${YELLOW}${BOLD}[*] Deploying and Executing Payload on ${VM_NAME}...${RESET}"
gcloud compute scp remote_payload.sh $VM_NAME:~ --zone=$ZONE --quiet
gcloud compute ssh $VM_NAME --zone=$ZONE --quiet --command="bash ~/remote_payload.sh"

rm remote_payload.sh

echo -e "\n${GREEN}${BOLD}>>> MISSION COMPLETE! Check all progress bars in Qwiklabs. <<<${RESET}"
