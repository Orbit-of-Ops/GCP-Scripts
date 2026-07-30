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
export REGION=$(gcloud config get-value compute/region 2>/dev/null)
if [ -z "$REGION" ] || [ "$REGION" == "(unset)" ]; then
    export ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
    export REGION=${ZONE%-*}
fi
if [ -z "$REGION" ] || [ "$REGION" == "(unset)" ]; then
    read -p "Please paste the REGION from your lab instructions (e.g. us-central1) and press Enter: " REGION </dev/tty
fi
gcloud config set compute/region $REGION

# 1. Enable APIs & Create external source connection
echo "Enabling AI Platform API..."
gcloud services enable aiplatform.googleapis.com

echo "Creating the external source connection (vector_conn)..."
bq mk --connection --location=$REGION --project_id=$PROJECT_ID --connection_type=CLOUD_RESOURCE vector_conn

# 2. Extract Service Account and assign IAM roles
echo "Fetching Service Account and assigning IAM roles..."
SERVICE_ACCOUNT=$(bq show --format=json --connection $PROJECT_ID.$REGION.vector_conn | jq -r '.cloudResource.serviceAccountId')

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/bigquery.dataOwner"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/storage.objectViewer"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT" --role="roles/aiplatform.user"

echo "Waiting 20 seconds for IAM policies to propagate..."
sleep 20

# 3. Create the Object Table
echo "Executing Task 2: Create an object table..."
bq query --use_legacy_sql=false "
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT_ID}.gcc_bqml_dataset.gcc_image_object_table\`
WITH CONNECTION \`${REGION}.vector_conn\`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://${PROJECT_ID}/*']
);"
sleep 10

# 4. Create the Embeddings Model
echo "Executing Task 3: Create the multimodal embedding model..."
bq query --use_legacy_sql=false "
CREATE OR REPLACE MODEL \`${PROJECT_ID}.gcc_bqml_dataset.gcc_embedding\`
REMOTE WITH CONNECTION \`${REGION}.vector_conn\`
OPTIONS (
  endpoint = 'multimodalembedding@001'
);"
sleep 10

# 5. Generate Embeddings
echo "Executing Task 3: Generate embeddings..."
bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`${PROJECT_ID}.gcc_bqml_dataset.gcc_retail_store_embeddings\` AS
SELECT *, REGEXP_EXTRACT(uri, r'[^/]+$') AS product_name
FROM ML.GENERATE_EMBEDDING(
  MODEL \`${PROJECT_ID}.gcc_bqml_dataset.gcc_embedding\`,
  TABLE \`${PROJECT_ID}.gcc_bqml_dataset.gcc_image_object_table\`
);"
sleep 10

# 6. Run Vector Search
echo "Executing Task 4: Run a vector search..."
bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`${PROJECT_ID}.gcc_bqml_dataset.gcc_vector_search_table\` AS
SELECT
  base.uri,
  base.product_name,
  base.content_type,
  distance
FROM VECTOR_SEARCH(
  TABLE \`${PROJECT_ID}.gcc_bqml_dataset.gcc_retail_store_embeddings\`,
  'ml_generate_embedding_result',
  (
    SELECT ml_generate_embedding_result AS embedding_col
    FROM ML.GENERATE_EMBEDDING(
      MODEL \`${PROJECT_ID}.gcc_bqml_dataset.gcc_embedding\`,
      (SELECT 'Men Sweaters' AS content)
    )
  ),
  top_k => 2,
  distance_type => 'COSINE'
);"

MAGENTA='\e[1;35m'
echo -e "\n${MAGENTA}${BOLD}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}║            🎉 AUTOMATION COMPLETED SUCCESSFULLY 🎉           ║${RESET}"
echo -e "${MAGENTA}${BOLD}╚════════════════════════════════════════════════════════════╝${RESET}"

# Subscribe to Orbit of Ops https://www.youtube.com/@orbitofops/videos
