#!/bin/bash

nsxtuser='admin'
nsxtpasswd='Illumio123!@#'
baseUrl='10.8.200.95'

query=$1

external_ids=$(curl --silent -k -u $nsxtuser:$nsxtpasswd -X GET "https://$baseUrl/policy/api/v1/fabric/virtual-machines" | jq -r --arg query "$query" '[.results[] | select(.display_name | test("^" + $query)) | .external_id] | join(",")')

echo "{\"external_ids\": \"$external_ids\"}"
