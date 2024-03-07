#!/usr/bin/env bash
# 
# Bash shell script that gets access information associated with a token using the Devo Provisioning API.
# 
#
# Version:  1.0.0
# Author:   Roberto Meléndez  [Cambridge, USA] 
# API Doc:  https://docs.devo.com/space/latest/177864705/Provisioning+API
# Released: March 7, 2024


set -euo pipefail


# USER SETTINGS

declare -r DEVO_API_KEY=YOUR-API-KEY-GOES-HERE
declare -r DEVO_API_SECRET=YOUR-API-SECRET-GOES-HERE
declare -r DEVO_TOKEN=YOUR-TOKEN-GOES-HERE

declare -r DEVO_CLOUD=us
declare -r ENDPOINT=https://api-${DEVO_CLOUD}.devo.com/probio
declare -r DOMAIN=mydomain


# Optional

# Comma-separated list of tables names to validate for access
declare -r TABLES="box.unix,cloud.office365.management,firewall.paloalto.traffic"
# Comma-separated list of policies to validate for access
declare -r POLICIES="policy.relays.manage,policy.alerts.manage,policy.lookups.view"


#######################################


http_request() {
  local url="${1}"
  local method="${2}"
  local data="${3}"

  local ts=$(echo "$(date +%s) * 1000" | bc)
  local sign=$(echo -n "${DEVO_API_KEY}${data}${ts}" | openssl dgst -sha256 -hmac "${DEVO_API_SECRET}" | awk '{ print $NF }')

  curl -sX "${method}" "${url}" \
       -H "Content-Type: application/json" \
       -H "x-logtrust-reseller-apikey: ${DEVO_API_KEY}" \
       -H "x-logtrust-timestamp: ${ts}" \
       -H "x-logtrust-sign: ${sign}" \
       -H "Authorization: Bearer ${DEVO_TOKEN}" \
       -d "${data}"
}


get_token_access() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/access"

  # Check if TABLES and/or POLICIES are provided
  if [[ -n "${TABLES:-}" ]]; then
    endpoint+="?tableAccess=${TABLES}"
    if [[ -n "${POLICIES:-}" ]]; then
      endpoint+="&policyAccess=${POLICIES}"
    fi
  elif [[ -n "${POLICIES:-}" ]]; then
    endpoint+="?policyAccess=${POLICIES}"
  fi

  echo -e "\nGET ${endpoint}"
  http_request "${endpoint}" "GET" ""
}


main() {
  get_token_access "${DOMAIN}"
}

main "$@"
