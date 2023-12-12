#!/usr/bin/env bash
# 
# Bash shell script that removes a user from an MSSP domain using the Devo Provisioning API.
# 
#
# Version:  1.0.1
# Author:   Roberto Meléndez  [Cambridge, USA] 
# API Doc:  https://docs.devo.com/space/latest/177864705/Provisioning+API
# Released: December 11, 2023


set -euo pipefail


# USER SETTINGS

declare -r DEVO_API_KEY=YOUR-MSSP-API-KEY-GOES-HERE
declare -r DEVO_API_SECRET=YOUR-MSSP-API-SECRET-GOES-HERE
declare -r DEVO_CLOUD=us
declare -r ENDPOINT=https://api-${DEVO_CLOUD}.devo.com/probio
declare -r USER=roberto@example.com
declare -r DOMAIN=("domain@reseller")


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

remove_user() {
  local user="${1}"
  local domain="${2}"
  local endpoint="${ENDPOINT}/user/email/${USER}/domain/${DOMAIN}"

  echo -e "\nDELETE ${endpoint}"
  http_request "${endpoint}" "DELETE" ""
}


get_users() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/user/domain/${domain}"

  echo -e "\nGET ${endpoint}"
  http_request "${endpoint}" "GET" ""
}


main() {
  remove_user "${USER}" "${DOMAIN}"
  get_users "${DOMAIN}"
}

main "$@"
