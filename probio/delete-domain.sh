#!/usr/bin/env bash
# 
# Bash shell script that deletes domains from an MSSP account using the Devo Provisioning API.
# 
#
# Version:  1.0.0
# Author:   Roberto Meléndez  [Cambridge, USA] 
# API Doc:  https://docs.devo.com/space/latest/177864705/Provisioning+API
# Released: January 23, 2024


set -euo pipefail


# USER SETTINGS

declare -r DEVO_API_KEY=YOUR-MSSP-API-KEY-GOES-HERE
declare -r DEVO_API_SECRET=YOUR-MSSP-API-SECRET-GOES-HERE

declare -r DEVO_CLOUD=us
declare -r ENDPOINT=https://api-${DEVO_CLOUD}.devo.com/probio
declare -r DOMAINS=("domain1@reseller" "domain2@reseller" "domain3@reseller")


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


delete_domain() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/domain/${domain}"

  echo -e "\nDELETE ${endpoint}"
  http_request "${endpoint}" "DELETE" ""
}


delete_domains() {
  for domain in "$@"; do
    delete_domain "${domain}"
  done
}


get_domain() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/domain/${domain}"

  echo -e "\nGET ${endpoint}"
  http_request "${endpoint}" "GET" ""
}


get_domains() {
  for domain in "${DOMAINS[@]}"; do
    get_domain "${domain}"
  done
}


main() {
  delete_domains "${DOMAINS[@]}"

  # Uncomment below to confirm that domains were successfully removed 
  #get_domains "${DOMAINS[@]}"
}

main "$@"
