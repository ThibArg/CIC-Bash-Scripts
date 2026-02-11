#!/bin/bash

# CIC Connection Script: An example of bash script to quickly test Knowledge Discovery with CIC.
# This is not production ready, it is for backup and learning purpose.
# License is Apache License, Version 2.0, do whatever you want with it, but no warranty at all.
#
# To use it:
#  - Set the expected env. variables for authentication and all:
#  - Change the FILE_PATH variable to point to the file you want to test with.
#  - Change the METADATA_JSON variable to set the enrichment you want to test with.
#    You can use the provided example or create your own.
#  - Run the script: ./cic-connection-script.sh
# Expect some env. variables for authentication and all:
#  CIC_AUTH_BASE_URL, CIC_DISCOVERY_CLIENT_ID, CIC_DISCOVERY_CLIENT_SECRET, CIC_DISCOVERY_BASE_URL and CIC_DISCOVERY_ENVIRONMENT

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
  "$CIC_DISCOVERY_CLIENT_ID" \
  "$CIC_DISCOVERY_CLIENT_SECRET" \
  "hxp hxp.integrations hxp.nucleus.account hxpr hxps environment_authorization iam.jti-capture:")"

# ============================================================
# Ask Question
# ============================================================
echo ""
echo "Asking question..."

# Nuxeo KD Demo Content HR Specialist: c9244d54-ac11-44e1-9a08-a738c0a56b57
agentId="c9244d54-ac11-44e1-9a08-a738c0a56b57"

read -r -d '' METADATA_JSON <<EOF
{
  "question": "As a full time employee recently hired, when can I take my first PTO?",
  "contextObjectIds": []
}
EOF

response_file="$(mktemp)"
# Auto delete on script exit
trap 'rm -f "$response_file"' EXIT
http_code=$(
  curl -sS -L \
    -o "$response_file" \
    -w "%{http_code}" \
    -X POST "$CIC_DISCOVERY_BASE_URL/agent/agents/$agentId/questions" \
    -H "Hxp-Environment: $CIC_DISCOVERY_ENVIRONMENT" \
    -H "Hxp-App: hxai-discovery" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: */*"  \
    --data-raw "$METADATA_JSON"
)

if [[ "$http_code" -ne 200 && "$http_code" -ne 202 ]]; then
  echo "Process call failed (HTTP $http_code)" >&2
  cat "$response_file" >&2
  echo ""
  exit 1
fi

question_id=$(jq -r '.questionId // empty' "$response_file")
if [[ -z "$question_id" ]]; then
  echo "questionId not found in response" >&2
  cat "$response_file" >&2
  exit 1
fi

echo "Asking question......DONE (id: $question_id)"

# ============================================================
# Get answer
# ============================================================
echo ""
echo "Now polling the answer..."
poll_kd_processing_results "$CIC_DISCOVERY_BASE_URL" "$question_id" "$TOKEN"


# ============================================================
# Done
# ============================================================
echo ""
echo "CALLING KE DONE"
echo ""
