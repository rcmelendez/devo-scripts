#!/usr/bin/env bash
# 
# Bash shell script that creates a new role in the given domain(s) using the Devo Provisioning API.
# 
#
# Version:  1.0.0
# Author:   Roberto Meléndez  [Cambridge, USA] 
# API Doc:  https://docs.devo.com/space/latest/177864705/Provisioning+API
# Released: December 12, 2023


set -euo pipefail


# USER SETTINGS

declare -r DEVO_API_KEY=YOUR-MSSP-API-KEY-GOES-HERE
declare -r DEVO_API_SECRET=YOUR-MSSP-API-SECRET-GOES-HERE
declare -r DEVO_CLOUD=us
declare -r ENDPOINT=https://api-${DEVO_CLOUD}.devo.com/probio
declare -r DOMAINS=("domain1@reseller" "domain2@reseller" "domain3@reseller")

declare -r ROLE='{
  "name": "Devo Users",
  "description": "Devo Users role",
  "policies": "*",
  "applications": ["app.custom.alertManagerAddOn"]
}'

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
       -d "${data}"
}


create_role() {
  local domain="${1}"
  local role="${2}"
  local endpoint="${ENDPOINT}/domain/${domain}/roles"

  echo -e "\nPOST ${endpoint}"
  http_request "${endpoint}" "POST" "${role}"
}


create_roles() {
  for domain in "${DOMAINS[@]}"; do
    create_role "${domain}" "${ROLE}"
  done
}


get_roles() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/domain/${domain}/roles"

  echo -e "\nGET ${endpoint}"
  http_request "${endpoint}" "GET" ""
}


get_roles_domains(){
  for domain in "${DOMAINS[@]}"; do
    get_roles "${domain}"
  done
}


main() {
  # Create the role
  create_roles "${DOMAINS[@]}"

  # Uncomment below to confirm that the role was successfully created
  #get_roles_domains "${DOMAINS[@]}"
}

main "$@"
