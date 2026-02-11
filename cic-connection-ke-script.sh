#!/bin/bash

# CIC Connection Script: An example of bash script to quickly test Knowledge Enrichment with CIC.
# This is not production ready, it is for backup and learning purpose.
# License is Apache License, Version 2.0, do whatever you want with it, but no warranty at all.
#
# To use it:
#  - Set the expected env. variables for authentication and all:
#    CIC_AUTH_BASE_URL, CIC_ENRICHMENT_CLIENT_ID, CIC_ENRICHMENT_CLIENT_SECRET, CIC_ENRICHMENT_BASE_URL
#  - Change the FILE_PATH variable to point to the file you want to test with.
#  - Change the METADATA_JSON variable to set the enrichment you want to test with.
#    You can use the provided example or create your own.
#  - Run the script: ./cic-connection-script.sh
# Expect some env. variables for authentication and all:
# CIC_AUTH_BASE_URL, CIC_ENRICHMENT_CLIENT_ID, CIC_ENRICHMENT_CLIENT_SECRET, CIC_ENRICHMENT_BASE_URL

# ============================================================
# Utilities: Authentication, pull results, ...
# ============================================================
source ./cic-connection-script-utils.sh

# ============================================================
# File to process
# ============================================================
FILE_PATH=/Users/`whoami`/Documents/Documents-for-import/0-1-Assets-to-import/For-Gen-DAM/SampleContract-v3.pdf
#FILE_PATH=/Users/`whoami`/Documents/Documents-for-import/0-1-Assets-to-import/For-Gen-DAM/Creative-Brief.pdf
#FILE_PATH=/Users/`whoami`/Documents/Documents-for-import/0-1-Assets-to-import/For-Gen-DAM/00-16-pages.pdf
MIME_TYPE=$(file --mime-type -b "$FILE_PATH")
ENCODED_MIME_TYPE="${MIME_TYPE//\//%2F}"
# Compute file size
CONTENT_LENGTH=$(stat -f %z "$FILE_PATH")

# ============================================================
# Authenticate
# ============================================================
echo "Getting a token..."
TOKEN="$(get_cic_bearer_token \
  "$CIC_AUTH_BASE_URL/connect/token" \
  "$CIC_ENRICHMENT_CLIENT_ID" \
  "$CIC_ENRICHMENT_CLIENT_SECRET" \
  "environment_authorization")"

# ============================================================
# Upload
# ============================================================
# Upload - 1: Presigned URL
echo ""
echo "Uploading file: $FILE_PATH with MIME type: $MIME_TYPE..."
echo "    * Get presigned URL..."
response=$(
  curl -sS -L \
    "$CIC_ENRICHMENT_BASE_URL/files/upload/presigned-url?contentType=$ENCODED_MIME_TYPE" \
    -H "Accept: */*" \
    -H "Authorization: Bearer $TOKEN"
)

presignedUrl=$(jq -r '.presignedUrl' <<< "$response")
objectKey=$(jq -r '.objectKey' <<< "$response")

# Upload - 2: Upload
echo "    * Upload..."
http_code=$(
  curl -sS -X PUT \
    -H "Content-Type: $MIME_TYPE" \
    --data-binary @"$FILE_PATH" \
    -o /dev/null \
    -w "%{http_code}" \
    "$presignedUrl"
)
if [[ "$http_code" != "200"  ]]; then
  echo "Upload failed: HTTP $http_code" >&2
  exit 1
fi

echo "Uploading file DONE"

# ============================================================
# Request enrichment
# ============================================================
if false; then
read -r -d '' METADATA_JSON <<EOF
{
  "version": "context.api/v2",
  "objectKeys": [{"path": "$objectKey"}],
  "actions": {
    "textMetadataGeneration": {
      "kSimilarMetadata": [
        {
          "documentDates": ["an ISO date"],
          "company": "",
          "peopleInvolved": [{"firstName": "a first name", "lastName": "a last name"}]
        }
      ],
      "instructions": {
        "general": "Assume this file is a contract",
        "documentDates": "Extract all the dates of the file and convert them to ISO 8601 (YYYY-MM-DD), set them in an array.",
        "company": "Search the file for a main company involved in the document. If you found no main company involved, do not set this metadata",
        "peopleInvolved": "Extract all the names, even if not complete (for example 'A. Earth') in an array of objects. Each object has a firstName and a lastName field. If the document is not a contract, do not set this metadata"
      }
    }
  }
}
EOF
fi

read -r -d '' METADATA_JSON <<EOF
{
  "objectKeys": [
    {
      "path": "$objectKey"
    }
  ],
  "version": "context.api/v2",
  "actions": {
    "textMetadataGeneration": {
      "kSimilarMetadata": [
        {
          "contractNumber": "AAABBB1234",
          "provider": "Someprovider",
          "contractor": "AContractor",
          "contractDate": "an ISO date",
          "documentDates": [{"aLabel": "an ISO date"}, {"otherLabel": "other IDO date"}],
          "peopleInvolved": [{"firstName": "a first name", "lastName": "a last name"}],
          "companiesInvolved": ["company1", "company2"],
          "confidence": [{"contractNumber": 0.00}, {"provider": 0.00}]
        }
      ],
      "instructions": {
        "general": "Assume this file is a contract.",
        "requirement": "If you find yourself setting the value of the metadata equals to the example, it means you could not extract the value, so, instead, set it to null.",
        "confidence": "For all metadata, retrun a value only if your level of confidence for this value is > 90%. If it is less, do not return the value. Also, for every metadata extracted, return the % of confidence you had extracting this metadata, then group all the values in an array of objects. For ezch object, the propertuy name is the name of the metadata and the value is the confidence (a number between 0 and 1)",
        "contractNumber": "Extract the contract number, which is usually a combination of letters and numbers, and is often labeled as 'Ref.:', 'Contract:', or similar in the document. Only extract the number, do not add a prefix or a suffix.",
        "provider": "Extract the name of the provider, referenced in the contract as 'the Provider'",
        "contractor": "Extract the name of the contractor, referenced in the contract as 'the Contractor'",
        "contractDate": "Extract the date of the contract and convert it to ISO 8601 (YYYY-MM-DD)",
        "documentDates": "Extact all the dates in the contract and convert them to ISO 8601 (YYYY-MM-DD), set them in an array of objects whose properties are the label explaining what the date is for. Do not dynamically calculate dates: For example, if the contract states a deadline is 10 days after the contract signature, ignore this date and do not return it at all.",
        "peopleInvolved": "Extract the names of all the people named in the contract, even if the name is not complete (for example 'A. Earth') in an array of objects. Each object has a firstName and a lastName field.",
        "companiesInvolved": "Extract the names of all the companies named in the contract in an array of strings."
      }
    }
  }
}
EOF

#echo "Metadata JSON to send:"
#echo "$METADATA_JSON" | jq .

echo ""
echo "Requesting enrichment..."
response_file="$(mktemp)"
# Auto delete on script exit
trap 'rm -f "$response_file"' EXIT
http_code=$(
  curl -sS -L \
    -o "$response_file" \
    -w "%{http_code}" \
    -X POST "$CIC_ENRICHMENT_BASE_URL/content/process" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: */*" \
    --data-raw "$METADATA_JSON"
)
if [[ "$http_code" -ne 200 ]]; then
  echo "Process call failed (HTTP $http_code)" >&2
  cat "$response_file" >&2
  exit 1
fi

processing_id=$(jq -r '.processingId // empty' "$response_file")
if [[ -z "$processing_id" ]]; then
  echo "processingId not found in response" >&2
  cat "$response_file" >&2
  exit 1
fi
echo "Requesting enrichment DONE"

# ============================================================
# get results
# ============================================================
echo ""
echo "Now polling for results for processingId: $processing_id..."
poll_ke_processing_results "$CIC_ENRICHMENT_BASE_URL" "$processing_id" "$TOKEN"


# ============================================================
# Done
# ============================================================
echo ""
echo "CALLING KE DONE"
echo ""
