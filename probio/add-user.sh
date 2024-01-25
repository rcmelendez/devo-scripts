#!/usr/bin/env bash
# 
# Bash shell script that adds a user to a common or multitenant domain using the Devo Provisioning API.
# 
#
# Version:  1.0.0
# Author:   Roberto Meléndez  [Cambridge, USA] 
# API Doc:  https://docs.devo.com/space/latest/177864705/Provisioning+API
# Released: January 25, 2024


set -euo pipefail


# USER SETTINGS

declare -r DEVO_API_KEY=YOUR-API-KEY-GOES-HERE
declare -r DEVO_API_SECRET=YOUR-API-SECRET-GOES-HERE
declare -r DEVO_CLOUD=us
declare -r ENDPOINT=https://api-${DEVO_CLOUD}.devo.com/probio

declare -r USER=roberto@example.com
declare -r DOMAIN=("mydomain")
declare -r ROLE="ADMIN"


#######################################


http_request() {
  local url="${1}"
  local method="${2}"
  local data="${3}"

  local ts=$(echo "$(date +%s) * 1000" | bc)
  local sign=$(echo -n "${DEVO_API_KEY}${data}${ts}" | openssl dgst -sha256 -hmac "${DEVO_API_SECRET}" | awk '{ print $NF }')

  DEVO_API_KEY_HEADER='x-logtrust-domain-apikey'
  [[ "${DOMAIN}" =~ "@" ]] && DEVO_API_KEY_HEADER='x-logtrust-reseller-apikey'

  curl -sX "${method}" "${url}" \
       -H "Content-Type: application/json" \
       -H "${DEVO_API_KEY_HEADER}: ${DEVO_API_KEY}" \
       -H "x-logtrust-timestamp: ${ts}" \
       -H "x-logtrust-sign: ${sign}" \
       -d "${data}"
}

add_user() {
  local user="${1}"
  local domain="${2}"
  local role="${3}"
  local endpoint="$ENDPOINT/user/internal"
  local data='{"email":"'"${user}"'","role":"'"${role}"'","domain": "'"${domain}"'"}'

  echo -e "\nPOST ${endpoint}"
  http_request "${endpoint}" "POST" "${data}"
}


get_users() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/user/domain/${domain}"

  echo -e "\nGET ${endpoint}"
  http_request "${endpoint}" "GET" ""
}


main() {
  add_user "${USER}" "${DOMAIN}" "${ROLE}"

  # Uncomment below to confirm that the user was successfully added 
  #get_users "${DOMAIN}"
}

main "$@"
