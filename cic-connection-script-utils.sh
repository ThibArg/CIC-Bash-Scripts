#!/bin/bash

# ========================================> Auth Token
get_cic_bearer_token() {
  local token_url="$1"
  local client_id="$2"
  local client_secret="$3"

  if [[ -z "$token_url" || -z "$client_id" || -z "$client_secret" ]]; then
    echo "Usage: get_bearer_token <url> <client_id> <client_secret>" >&2
    return 1
  fi

  urlencode() {
    local s="$1" out="" i c
    for ((i=0;i<${#s};i++)); do
      c="${s:i:1}"
      case "$c" in
        [a-zA-Z0-9.~_-]) out+="$c" ;;
        *) printf -v out '%s%%%02X' "$out" "'$c" ;;
      esac
    done
    printf '%s' "$out"
  }

  local body
  body="client_id=$(urlencode "$client_id")&client_secret=$(urlencode "$client_secret")&grant_type=client_credentials&scope=environment_authorization"

  local content_length
  content_length=$(LC_ALL=C printf '%s' "$body" | wc -c | tr -d ' ')

  local response_file
  response_file="$(mktemp)"
  trap 'rm -f "$response_file"' RETURN

  local http_code
  http_code=$(
    curl -sS -L \
      -o "$response_file" \
      -w "%{http_code}" \
      -X POST "$token_url" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -H "Content-Length: $content_length" \
      --data-raw "$body"
  )

  if [[ "$http_code" -ne 200 ]]; then
    echo "Token request failed (HTTP $http_code)" >&2
    cat "$response_file" >&2
    return 1
  fi

  jq -r '.access_token // empty' "$response_file"
}

# ========================================> Polling KE Results
poll_processing_results() {
  local base_url="$1"
  local processing_id="$2"
  local token="$3"

  if [[ -z "$base_url" || -z "$processing_id" || -z "$token" ]]; then
    echo "Usage: poll_processing_results <base_url> <processing_id> <token>" >&2
    return 1
  fi

  local url="${base_url%/}/content/process/${processing_id}/results"

  local interval=5
  local timeout=60
  local max_tries=$((timeout / interval))

  local i http_code response_file
  response_file="$(mktemp)"
  trap 'rm -f "$response_file"' RETURN

  for ((i=1; i<=max_tries; i++)); do
    http_code=$(
      curl -sS -L \
        -o "$response_file" \
        -w "%{http_code}" \
        -X GET "$url" \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json"
    )

    if [[ "$http_code" -eq 200 ]]; then
      # Pretty-print JSON and return success
      jq '.' "$response_file"
      return 0
    fi

    if [[ "$http_code" -eq 202 ]]; then
      echo "[$i/$max_tries] Still processing (HTTP 202). Retrying..." >&2
      sleep "$interval"
      continue
    fi

    echo "Error while polling results (HTTP $http_code)" >&2
    cat "$response_file" >&2
    return 1
  done

  echo "Timeout after ${timeout}s waiting for results." >&2
  cat "$response_file" >&2
  return 1
}
