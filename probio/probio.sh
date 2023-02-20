#!/usr/bin/env bash
# 
# Bash script that performs requests using the Devo Provisioning API.
#
#
# Version:      1.0.3
# Author:       Roberto Meléndez  [Cambridge, USA]
# Github:       https://github.com/rcmelendez/devo-scripts/probio/
# API Doc:      https://docs.devo.com/confluence/ndt/latest/api-reference/provisioning-api
# Devo Connect: https://community.devo.com/data-ingestion-68/how-to-run-provisioning-api-requests-with-a-bash-script-125
# Released:     June 9, 2021
# Updated:      Feburary 20, 2023


set -euo pipefail

#######################################
# USER SETTINGS
#
# Uncomment if DEVO_API_KEY and/or DEVO_API_SECRET variables are not already defined in
# your shell startup file (e.g. .zshrc, .bashrc, etc)
# declare -r DEVO_API_KEY=YOUR-API-KEY
# declare -r DEVO_API_SECRET=YOUR-API-SECRET

# Environment
# Available clouds: us, eu, ca, sasr, apac
declare -r DEVO_CLOUD=us
declare -r PROBIO_URL=https://api-${DEVO_CLOUD}.devo.com/probio

# Domain & Reseller
declare -r DOMAIN=roberto_test
# Leave it blank if this is not a reseller
declare -r RESELLER=partnerservicesmssp

if [[ -n "${RESELLER}" ]]; then 
  DEVO_DOMAIN="${DOMAIN}@${RESELLER}"
else
  DEVO_DOMAIN=${DOMAIN}
fi

# Use correct header for resellers
DEVO_API_KEY_HEADER='x-logtrust-domain-apikey'
[[ "${DEVO_DOMAIN}" =~ "@" ]] && DEVO_API_KEY_HEADER='x-logtrust-reseller-apikey'

# User
declare -r USER=roberto.melendez@devo.com

# HTTP method (GET, POST, PUT, or DELETE)
declare -r METHOD=GET

# Operation
# List all domains from reseller
declare -r OPERATION=/domain

# Get domain info
#declare -r OPERATION="/domain/${DEVO_DOMAIN}"

# Get reseller plans
#declare -r OPERATION="/plan"

# Get domain roles
#declare -r OPERATION="/domain/${DEVO_DOMAIN}/roles"

# Get user info
#declare -r OPERATION=/user/email/${USER}

# Get info about users in a domain
#declare -r OPERATION=/user/domain/${DEVO_DOMAIN}

# Get user info based on email and domain
#declare -r OPERATION=/user/email/${USER}/domain/${DEVO_DOMAIN}

# Get user info based on domain and internal ID
#declare -r OPERATION=/user/internal/4eb3367a-56cc-1b32-a6c9-174d3f227553/domain/${DEVO_DOMAIN}

# Add an internal user to a domain
#declare -r OPERATION=/user/internal?skipMailValidation=true

# Enable an inactive user
#declare -r OPERATION=/user/email/${USER}/domain/${DEVO_DOMAIN}/enable


# Body
# Empty value if using GET
declare -r DATA=''

# Create a new domain
#declare -r DATA='{"name":"roberto_test","plan":"child","time":0.03333333333333333,"volume":0.5},"status":"Active"'

# Create a new role
#declare -r DATA='{"name": "Devo Users", "description": "Devo Users role created via Provisioning API", "policies": ["*"]}'

# Create a new internal user
#declare -r DATA='{"userName":"Probio Test User","email":"'${USER}'","role":"NO_PRIVILEGES","domain":"'${DEVO_DOMAIN}'"}'

# Add internal user to a domain
#declare -r DATA='{"domain":"'${DEVO_DOMAIN}'","email":"'${USER}'","externalId":"4eb3367a-56cc-1b32-a6c9-174d3f227553","role":"ADMIN","owner":false}'

#######################################


declare -r API_ENDPOINT="${PROBIO_URL}${OPERATION}"
declare -i timestamp
timestamp=$(echo "`date +%s` * 1000" | bc)
declare -r MESSAGE="${DEVO_API_KEY}${DATA}${timestamp}"
signature=$(echo -n "${MESSAGE}" | openssl dgst -sha256 -hmac "${DEVO_API_SECRET}" | awk '{ print $NF }')


# RESULTS

echo "${METHOD} ${OPERATION}"

output=$(curl -s -w "%{time_total}" -X ${METHOD} "${API_ENDPOINT}" \
  -H "Content-Type: application/json" \
  -H "cache-control: no-cache" \
  -H "${DEVO_API_KEY_HEADER}: ${DEVO_API_KEY}" \
  -H "x-logtrust-timestamp: ${timestamp}" \
  -H "x-logtrust-sign: ${signature}" \
  -d "${DATA}") 


# Display the JSON output in pretty format if jq is installed
if [[ -x "$(command -v jq)" ]]; then
  echo "${output}" | jq
else
  echo "${output}"
fi