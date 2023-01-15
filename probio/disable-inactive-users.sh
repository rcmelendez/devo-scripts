#!/usr/bin/env bash
# 
# Bash script that disables inactive users from a Devo domain that have not logged in to 
# the platform for a given period of time. The script will ignore the domain owner.
# 
# It's helpful for PCI Data Security Standard (PCI DSS) compliance.
# PCI DSS Requirement 8.1.4: Remove or disable inactive user accounts within 90 days.
#
# 
# Version:       1.0.0
# Author:        Roberto Meléndez  [Cambridge, USA]
# Github:        https://github.com/rcmelendez/devo-scripts/probio/
# Devo Connect:  https://community.devo.com/community
# Released:      January 15, 2023


set -euo pipefail


#######################################
# USER SETTINGS
#
# Provide your Devo API key and API secret below or as environment variables
# in your shell startup file (e.g. .zshrc, .bashrc, etc)
declare -r DEVO_API_KEY=
declare -r DEVO_API_SECRET=

# Devo cloud
# Available regions: us, eu, ca, sasr, or apac
declare -r DEVO_CLOUD=us

# Devo domain
# For resellers, use the format: domain@reseller
declare -r DEVO_DOMAIN=roberto

# Time period
# Choose between two options:
# - relative date (recommended): 7d, 24h, 90d, etc.
# - epoch timestamp in SECONDS (NOT millisecs): 1673593200 (2023-01-13 07:00:00 UTC)
# The script supports the same date formats as the Query API: 
# https://docs.devo.com/space/latest/95128301/Running+queries+with+the+Query+API#Relative-dates
declare -r FROM=90d

# END OF USER SETTINGS
#######################################


declare -r NC='\e[0m'
declare -r GR='\e[0;32m'
declare -r BG='\e[1;32m'
declare -r BR='\e[1;31m'
declare -r TICK="[${BG}✓${NC}]"
declare -r CROSS="[${BR}×${NC}]"
declare -r INFO='[i]'
declare -i timestamp
declare -r PROBIO_URL="https://api-${DEVO_CLOUD}.devo.com/probio"
declare -r QUERY_API_URL="https://apiv2-${DEVO_CLOUD}.devo.com/search/query"
OS=$(uname -s)


error() {
  printf '%b' "${CROSS} Error: ${1}" >&2
}


# Validate if jq is installed
if [[ -z "$(command -v jq)" ]]; then 
  error "unable to find 'jq'. You can install it by typing:\n"
  [[ "${OS}" == "Linux" ]] && printf '%b' "Ubuntu: ${GR}sudo apt${NC} install jq\nCentOS: ${GR}sudo dnf${NC} install jq" && exit 1
  [[ "${OS}" == "Darwin" ]] && printf '%b' "${GR}brew${NC} install jq" && exit 1
fi


# Use correct header for resellers
API_KEY_HEADER='x-logtrust-domain-apikey'
[[ "${DEVO_DOMAIN}" =~ "@" ]] && API_KEY_HEADER='x-logtrust-reseller-apikey'


no_error() {
  local msg code
  if [[ $(echo "${1}" | jq 'type!="array" and has("error")') == true ]]; then
    if [[ $(echo "${1}" | jq 'has("cid")') == true ]]; then
      msg=$(echo "${1}" | jq -r '.object[]') && error "${msg}"
    else
      msg=$(echo "${1}" | jq -r '.error.message')
      code=$(echo "${1}" | jq '.error.code')
      error "${code}: ${msg}"
    fi
    return 1
  fi    
}


get_length() {
  echo "${1}" | jq 'length'
}


create_signature() {
  local data='' msg
  (( $# > 0 )) && data="${1}"
  timestamp=$(echo "$(date +%s) * 1000" | bc)
  msg="${DEVO_API_KEY}${data}${timestamp}"
  signature=$(echo -n "${msg}" | openssl dgst -sha256 -hmac "${DEVO_API_SECRET}" | awk '{ print $NF }')
}


get_users() {
  curl -sS --connect-timeout 10 -X GET "${PROBIO_URL}/user/domain/${DEVO_DOMAIN}" \
       -H "Content-Type: application/json" \
       -H "${API_KEY_HEADER}: ${DEVO_API_KEY}" \
       -H "x-logtrust-timestamp: ${timestamp}" \
       -H "x-logtrust-sign: ${signature}" \
       -d "" 2>&1
}


get_active_users() {
  local users
  create_signature
  users=$(get_users)
  if [[ "${users}" =~ "curl:" ]]; then
    error "$(echo "${users}" | awk 'NR==1')" && exit 1
  fi
  no_error "${users}" && echo "${users}" | jq 'map(select(.status=="active"))' || exit 1
}


get_logged_users() {
  local query users
  query='{"query":"from siem.logtrust.web.activity group every - select collectdistinct(username) as user","from":"'${FROM}'","to":"now","mode":{"type":"json/simple"}}'
  create_signature "${query}"
  users=$(curl -sS --connect-timeout 10 -X POST "${QUERY_API_URL}" \
               -H "Content-Type: application/json" \
               -H "x-logtrust-apikey: ${DEVO_API_KEY}" \
               -H "x-logtrust-timestamp: ${timestamp}" \
               -H "x-logtrust-sign: ${signature}" \
               -d "${query}")
  no_error "${users}" && echo "${users}" | jq '.user' || exit 1
}


get_inactive_users() {
  local activeUsers loggedUsers len noun='users' verb='have'
  activeUsers=$(get_active_users)
  loggedUsers=$(get_logged_users)
  len=$(get_length "${activeUsers}")
  (( len == 1 )) && noun='user'
  printf '%b' "${INFO} ${len} active ${noun} found."
  # Ignore domain owner 
  activeUsers=$(echo "${activeUsers}" | jq 'map(select(.owner == false) | .email)')
  inactiveUsers=$(jq -n "$activeUsers - $loggedUsers")
  len_inactive=$(get_length "${inactiveUsers}")
  (( len_inactive == 0 )) && printf '%b' "\n${CROSS} All users have logged in to Devo. Nothing to do :)" && exit 1
  (( len_inactive == 1 )) && noun='user' verb='has'
  printf '%b' "\n${INFO} ${len_inactive} ${noun} ${verb} not logged in to Devo:\n\n"
  echo "${inactiveUsers}" | jq -rc '.[]'
}


disable_users() {
  local msg='Users' users
  get_inactive_users
  for user in $(echo "${inactiveUsers}" | jq -rc '.[]'); do
    create_signature
    users=$(curl -sS --connect-timeout 10 -X POST "${PROBIO_URL}/user/email/${user}/domain/${DEVO_DOMAIN}/disable" \
	         -H "Content-Type: application/json" \
	         -H "${API_KEY_HEADER}: ${DEVO_API_KEY}" \
	         -H "x-logtrust-timestamp: ${timestamp}" \
	         -H "x-logtrust-sign: ${signature}" \
	         -d "")
  done
  if no_error "${users}"; then
    (( len_inactive == 1 )) && msg='User'
    printf '%b' "\n${TICK} ${GR}${msg} succesfully disabled.${NC}"
  fi
}


main() {
  disable_users
}

main "$@"
