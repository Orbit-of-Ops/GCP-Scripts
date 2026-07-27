#!/bin/bash
# ==============================================================================
# Color Variables & Branding
# ==============================================================================
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
RED='\e[1;31m'
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
echo -e "${MAGENTA}${BOLD}>>> ORBIT OF OPS: ARC116 MASTER AUTOMATION INITIALIZED <<<${RESET}\n"

export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo -e "${YELLOW}${BOLD}[*] Project ID: ${PROJECT_ID}${RESET}\n"

# ==============================================================================
# Task 1: Redact Sensitive Data
# ==============================================================================
echo -e "${BLUE}${BOLD}[Orbit of Ops] Task 1: Creating redact-request.json...${RESET}"
cat > redact-request.json <<EOF_END
{
	"item": {
		"value": "Please update my records with the following information:\n Email address: foo@example.com,\nNational Provider Identifier: 1245319599"
	},
	"deidentifyConfig": {
		"infoTypeTransformations": {
			"transformations": [{
				"primitiveTransformation": {
					"replaceWithInfoTypeConfig": {}
				}
			}]
		}
	},
	"inspectConfig": {
		"infoTypes": [{
				"name": "EMAIL_ADDRESS"
			},
			{
				"name": "US_HEALTHCARE_NPI"
			}
		]
	}
}
EOF_END

echo -e "${CYAN}${BOLD}[Orbit of Ops] Task 1: Calling DLP API to de-identify content...${RESET}"
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" https://dlp.googleapis.com/v2/projects/$PROJECT_ID/content:deidentify -d @redact-request.json -o redact-response.txt

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Task 1: Uploading de-identified content to Cloud Storage...${RESET}"
gsutil cp redact-response.txt gs://$PROJECT_ID-redact > /dev/null 2>&1

# ==============================================================================
# Task 2: Create DLP Inspection Templates
# ==============================================================================
echo -e "${MAGENTA}${BOLD}[Orbit of Ops] Task 2: Creating and uploading structured data template...${RESET}"
cat <<EOF > template_structured.json
{
  "deidentifyTemplate": {
    "deidentifyConfig": {
      "recordTransformations": {
        "fieldTransformations": [
          {
            "fields": [
              { "name": "bank name" },
              { "name": "zip code" }
            ],
            "primitiveTransformation": {
              "characterMaskConfig": {
                "maskingCharacter": "#"
              }
            }
          },
          {
            "fields": [
              { "name": "message" }
            ],
            "infoTypeTransformations": {
              "transformations": [
                {
                  "primitiveTransformation": {
                    "replaceWithInfoTypeConfig": {}
                  }
                }
              ]
            }
          }
        ]
      }
    },
    "displayName": "structured_data_template"
  },
  "locationId": "us",
  "templateId": "structured_data_template"
}
EOF
curl -X POST -s -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d @template_structured.json "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/deidentifyTemplates" > /dev/null

echo -e "${BLUE}${BOLD}[Orbit of Ops] Task 2: Creating and uploading unstructured data template...${RESET}"
cat > template_unstructured.json <<'EOF_END'
{
  "deidentifyTemplate": {
    "deidentifyConfig": {
      "infoTypeTransformations": {
        "transformations": [
          {
            "primitiveTransformation": {
              "replaceConfig": {
                "newValue": {
                  "stringValue": "[redacted]"
                }
              }
            }
          }
        ]
      }
    },
    "displayName": "unstructured_data_template"
  },
  "templateId": "unstructured_data_template"
}
EOF_END
curl -X POST -s -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d @template_unstructured.json "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/deidentifyTemplates" > /dev/null

# ==============================================================================
# Task 3: Configure Job Trigger
# ==============================================================================
echo -e "${CYAN}${BOLD}[Orbit of Ops] Task 3: Building DLP job-configuration.json...${RESET}"
cat > job-configuration.json << EOM
{
  "triggerId": "dlp_job",
  "jobTrigger": {
    "triggers": [
      {
        "schedule": {
          "recurrencePeriodDuration": "604800s"
        }
      }
    ],
    "inspectJob": {
      "actions": [
        {
          "deidentify": {
            "fileTypesToTransform": [
              "TEXT_FILE",
              "IMAGE",
              "CSV",
              "TSV"
            ],
            "transformationDetailsStorageConfig": {},
            "transformationConfig": {
              "deidentifyTemplate": "projects/$PROJECT_ID/locations/us/deidentifyTemplates/unstructured_data_template",
              "structuredDeidentifyTemplate": "projects/$PROJECT_ID/locations/us/deidentifyTemplates/structured_data_template"
            },
            "cloudStorageOutput": "gs://$PROJECT_ID-output"
          }
        }
      ],
      "inspectConfig": {
        "infoTypes": [
          {"name": "EMAIL_ADDRESS"},
          {"name": "PERSON_NAME"},
          {"name": "PHONE_NUMBER"},
          {"name": "CREDIT_CARD_NUMBER"}
        ],
        "minLikelihood": "POSSIBLE"
      },
      "storageConfig": {
        "cloudStorageOptions": {
          "filesLimitPercent": 100,
          "fileTypes": [
            "TEXT_FILE",
            "IMAGE",
            "WORD",
            "PDF",
            "AVRO",
            "CSV",
            "TSV",
            "EXCEL",
            "POWERPOINT"
          ],
          "fileSet": {
            "regexFileSet": {
              "bucketName": "$PROJECT_ID-input",
              "includeRegex": [],
              "excludeRegex": []
            }
          }
        }
      }
    },
    "status": "HEALTHY"
  }
}
EOM

echo -e "${YELLOW}${BOLD}[Orbit of Ops] Task 3: Sending job configuration to DLP API...${RESET}"
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/jobTriggers -d @job-configuration.json > /dev/null

echo -e "${RED}${BOLD}[Orbit of Ops] Sleeping for 60 seconds to ensure the job trigger registers in the backend...${RESET}"
for ((i=60; i>=1; i--)); do
  echo -ne "\r${CYAN}${BOLD}Time remaining: ${i} seconds...${RESET}"
  sleep 1
done
echo -e "\n"

echo -e "${MAGENTA}${BOLD}[Orbit of Ops] Task 3: Activating DLP job trigger...${RESET}"
curl -s -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "X-Goog-User-Project: $PROJECT_ID" "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/locations/us/jobTriggers/dlp_job:activate" > /dev/null

# ==============================================================================
# Cleanup & Completion
# ==============================================================================
rm redact-request.json redact-response.txt template_structured.json template_unstructured.json job-configuration.json arc116.sh 2>/dev/null

echo -e "\n${GREEN}${BOLD}🎉 Congratulations For Completing The Lab !!!${RESET}"
echo -e "${GREEN}${BOLD}>>> MISSION COMPLETE! Check all progress bars in Qwiklabs. <<<${RESET}"
