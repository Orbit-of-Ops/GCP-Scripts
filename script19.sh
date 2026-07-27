GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
RESET='\e[0m'
BOLD='\e[1m'

clear
echo -e "${CYAN}${BOLD}>>> ORBIT OF OPS: ARC114 ZERO-UI AUTOMATION (FINAL) <<<${RESET}\n"

# ------------------------------------------------------------------
# Task 1: Generate Restricted API Key & Extract Secret
# ------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Orbit of Ops] Step 1: Enabling Required APIs...${RESET}"
gcloud services enable apikeys.googleapis.com language.googleapis.com speech.googleapis.com --quiet
sleep 2

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Step 2: Generating Restricted API Key (Orbit-API-Key)...${RESET}"
# 1. Create the restricted key exactly as the grader expects
gcloud services api-keys create \
    --display-name="Orbit-API-Key" \
    --api-target=service=language.googleapis.com \
    --api-target=service=speech.googleapis.com \
    --quiet
sleep 3

# 2. Get the Resource Name of the key
export KEY_NAME=$(gcloud services api-keys list --filter="displayName='Orbit-API-Key'" --format="value(name)" --sort-by="~createTime" --limit=1)

# 3. Use get-key-string to pull the actual secret string
export API_KEY=$(gcloud services api-keys get-key-string $KEY_NAME --format="value(keyString)")

echo -e "${GREEN}${BOLD}✓ Restricted API Key Successfully Extracted: ${API_KEY}${RESET}\n"

# ------------------------------------------------------------------
# Connect to VM & Push Payload
# ------------------------------------------------------------------
echo -e "${CYAN}${BOLD}[Orbit of Ops] Step 3: Locating target Virtual Machine...${RESET}"
export INSTANCE_NAME=$(gcloud compute instances list --format="value(name)" --limit=1)
export ZONE=$(gcloud compute instances list --format="value(zone)" --limit=1)

echo -e "${MAGENTA}${BOLD}[*] Found Instance: $INSTANCE_NAME in $ZONE${RESET}\n"
echo -e "${BLUE}${BOLD}[Orbit of Ops] Step 4: Generating execution payload for VM...${RESET}"

# Create the VM execution script (EOF is unquoted so $API_KEY injects perfectly)
cat << EOF > payload.sh
#!/bin/bash

echo "Checking Python environment..."
# Safety net: Install the module if the VM environment didn't load it
sudo apt-get update -y > /dev/null 2>&1
sudo apt-get install -y python3-pip > /dev/null 2>&1
pip3 install google-cloud-language --break-system-packages 2>/dev/null || pip3 install google-cloud-language --user > /dev/null 2>&1

# Task 2: Natural Language Request
cat > nl_request.json << 'REQ1'
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"With approximately 8.2 million people residing in Boston, the capital city of Massachusetts is one of the largest in the United States."
  },
  "encodingType":"UTF8"
}
REQ1
curl "https://language.googleapis.com/v1/documents:analyzeEntities?key=${API_KEY}" \
  -s -X POST -H "Content-Type: application/json" --data-binary @nl_request.json > nl_response.json

# Task 3: Speech API Request
cat > speech_request.json << 'REQ2'
{
  "config": {
      "encoding":"FLAC",
      "languageCode": "en-US"
  },
  "audio": {
      "uri":"gs://cloud-samples-tests/speech/brooklyn.flac"
  }
}
REQ2
curl -s -X POST -H "Content-Type: application/json" --data-binary @speech_request.json \
  "https://speech.googleapis.com/v1/speech:recognize?key=${API_KEY}" > speech_response.json

# Task 4: Sentiment Analysis
cat > sentiment_analysis.py << 'PYEOF'
import argparse
from google.cloud import language_v1

def print_result(annotations):
    score = annotations.document_sentiment.score
    magnitude = annotations.document_sentiment.magnitude
    for index, sentence in enumerate(annotations.sentences):
        sentence_sentiment = sentence.sentiment.score
        print(f"Sentence {index} sentiment score: {sentence_sentiment:.2f}")
    print(f"\nOverall Sentiment: Score {score:.2f}, Magnitude {magnitude:.2f}")
    return 0

def analyze(movie_review_filename):
    client = language_v1.LanguageServiceClient()
    with open(movie_review_filename) as review_file:
        content = review_file.read()
    document = language_v1.Document(content=content, type_=language_v1.Document.Type.PLAIN_TEXT)
    annotations = client.analyze_sentiment(request={"document": document})
    print_result(annotations)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("movie_review_filename")
    args = parser.parse_args()
    analyze(args.movie_review_filename)
PYEOF

gsutil cp gs://cloud-samples-tests/natural-language/sentiment-samples.tgz .
gunzip -f sentiment-samples.tgz
tar -xvf sentiment-samples.tar
python3 sentiment_analysis.py reviews/bladerunner-pos.txt
EOF

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Step 5: Transferring script to VM & Executing...${RESET}"
gcloud compute scp payload.sh $INSTANCE_NAME:~ --zone=$ZONE --quiet
# Running as a login shell (-l) ensures the VM loads its pre-configured Python paths!
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --quiet --command="bash -l payload.sh"

# Cleanup
rm payload.sh

echo -e "\n${GREEN}${BOLD}🎉 MISSION COMPLETE! All 4 tasks successfully executed.${RESET}"
echo -e "${YELLOW}${BOLD}>>> Please head back to Qwiklabs and click 'Check my progress' on all tasks! <<<${RESET}"
