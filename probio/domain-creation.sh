#!/usr/bin/env bash
# 
# Bash shell script that creates domains for an MSSP account and 
# assigns a domain owner using the Devo Provisioning API.
# 
#
# Version:  1.0.0
# Author:   Roberto Meléndez  [Cambridge, USA] 
# API Doc:  https://docs.devo.com/space/latest/177864705/Provisioning+API
# Released: December 1, 2023


set -euo pipefail


# USER SETTINGS

declare -r DEVO_API_KEY=YOUR-MSSP-API-KEY-GOES-HERE
declare -r DEVO_API_SECRET=YOUR-MSSP-API-SECRET-GOES-HERE
declare -r DEVO_CLOUD=us
declare -r ENDPOINT=https://api-${DEVO_CLOUD}.devo.com/probio
declare -r OWNER=roberto@example.com

declare -r DOMAINS=("domain1@reseller" "domain2@reseller" "domain3@reseller")
declare -r PLAN=child


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


get_users_domains(){
  for domain in "$@"; do
    get_users "${domain}"
  done
}


create_domain() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/domain"
  local data='{"name":"'"${domain}"'","plan":"'"${PLAN}"'"}'

  echo "POST ${endpoint}"
  http_request "${endpoint}" "POST" "${data}"
}


create_domains() {
  for domain in "$@"; do
    create_domain "${domain}"
    add_user "${OWNER}" "${domain}" "OWNER"
  done
}


get_domain() {
  local domain="${1}"
  local endpoint="${ENDPOINT}/domain/${domain}"

  echo -e "\nGET ${endpoint}"
  http_request "${endpoint}" "GET" ""
}


get_domains() {
  for domain in "$@"; do
    get_domain "${domain}"
  done
}


main() {
  create_domains "${DOMAINS[@]}"
  
  # Uncomment below to confirm that domains and owners were successfully created 
  #get_users_domains "${DOMAINS[@]}"
  #get_domains "${DOMAINS[@]}"
}

main "$@"
