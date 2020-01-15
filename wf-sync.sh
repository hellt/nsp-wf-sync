#!/bin/bash
###############################################
# author: Roman Dodin                         #
# contact: roman.dodin@nokia.com              #
# repo: https://github.com/hellt/nsp-wf-sync  #
###############################################

# IP address or the domain name of the NSP server (without http(s) schema)
NSP_URL=$1

# path to the workflow file
WF_FILE=$2

# ID of the workflow; you can get the workflows and the corresponding IDs by calling `bash wf_sync.sh nsp_ip list_workflows`
WF_ID=$3

# http proxy which will be used by curl if set
HTTP_PROXY=$4

function check_args() {
    if [ -z "$NSP_URL" ]; then
        echo "ERROR: NSP URL should be supplied as the first positional argument"
        echo "usage: bash wf-sync.sh <nsp_address> <path_to_workflow_file> <workflow_id> [<http_proxy>]"
        exit 1
    fi

    if [ "$WF_FILE" != "list_workflows" ]; then
        if [ -z "$WF_FILE" ]; then
            echo "ERROR: workflow file path should be supplied as the second positional argument"
            echo "usage: bash wf-sync.sh <nsp_address> <path_to_workflow_file> <workflow_id> [<http_proxy>]"
            exit 1
        fi

        if [ ! -f "$WF_FILE" ]; then
            echo "ERROR: workflow file specified by the path (${WF_FILE}) was not found"
            exit 1
        fi
        # echo "WFID:${WF_ID}"
        if [ -z "$WF_ID" ]; then
            echo "ERROR: workflow ID should be supplied as the third positional argument"
            echo "usage: bash wf-sync.sh <nsp_ip> <path_to_workflow_file> <workflow_id> [<http_proxy>]"
            echo "you can list the workflows and their IDs with 'bash wf-sync.sh <nsp_address> list_workflows [<http_proxy >]' command"
            exit 1
        fi
    fi
}

function get_workflows() {
    get_access_token

    echo "Getting current workflows..."
    OUTPUT=$(
        curl -skL ${HTTP_PROXY_CMD} "https://${NSP_URL}:8546/wfm/api/v1/workflow?sort_dirs=desc&sort_keys=created_at" \
            --header 'Content-Type: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}"
    )

    RESP_CODE=$(echo $OUTPUT | jq .response.status)
    if [ "$RESP_CODE" != "200" ]; then
        echo "Failed to list workflows, HTTP Code $RESP_CODE"
        exit 1
    fi

    echo $OUTPUT | jq -r '.response.data[] | {id: .id, name: .name, status: .details.status, last_updated: .details.last_modified_at}'
}

function get_access_token() {
    # get access_token
    echo "Getting access token..."

    ACCESS_TOKEN=$(curl -skLN ${HTTP_PROXY_CMD} --request POST "https://${NSP_URL}/rest-gateway/rest/api/v1/auth/token" \
        --header 'Content-Type: application/json' \
        --header 'Authorization: Basic YWRtaW46Tm9raWFOc3AxIQ==' \
        --data-raw '{
"grant_type":"client_credentials"
}' | jq --raw-output '.access_token')
}

if [ "$WF_FILE" == "list_workflows" ]; then
    # http proxy
    HTTP_PROXY=$3

    if [ -z "$HTTP_PROXY" ]; then
        HTTP_PROXY_CMD=""
    else
        HTTP_PROXY_CMD="-x ${HTTP_PROXY}"
    fi

    get_workflows
    exit 0
fi

if [ -z "$HTTP_PROXY" ]; then
    HTTP_PROXY_CMD=""
else
    HTTP_PROXY_CMD="-x ${HTTP_PROXY}"
fi

check_args

get_access_token

echo "Setting workflow status to DRAFT..."
OUTPUT=$(curl -skL ${HTTP_PROXY_CMD} --request PUT "https://${NSP_URL}:8546/wfm/api/v1/workflow/${WF_ID}/status" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --data-binary '{"status":"DRAFT"}')

RESP_CODE=$(echo $OUTPUT | jq .response.status)
if [ "$RESP_CODE" != "200" ]; then
    echo "Setting to DRAFT failed, HTTP Code $RESP_CODE"
    exit 0
fi

echo "Validating the workflow..."
WF_BODY=$(cat ${WF_FILE})

OUTPUT=$(curl -skL ${HTTP_PROXY_CMD} --request POST "https://${NSP_URL}:8546/wfm/api/v1/workflow/validate" \
    --header 'Content-Type: text/plain' \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --data-binary "${WF_BODY}" \
    --compressed)

RESP_CODE=$(echo $OUTPUT | jq .response.status)
if [ "$RESP_CODE" != "200" ]; then
    echo "Call to validation endpoint failed, HTTP Code $RESP_CODE"
    exit 0
fi

VALID_STATUS=$(echo $OUTPUT | jq --raw-output .response.data.valid)
if [ "$VALID_STATUS" == "false" ]; then
    echo "Validation failed!"
    ERR=$(echo $OUTPUT | jq -r '.response.data.error')
    echo "Error: $ERR"
    exit 1
fi

echo "Updating the workflow definition..."
OUTPUT=$(curl -skL ${HTTP_PROXY_CMD} --request PUT "https://${NSP_URL}:8546/wfm/api/v1/workflow/${WF_ID}/definition?provider=LOCAL%20NSP%20USER" \
    --header 'Content-Type: text/plain' \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --data-binary "${WF_BODY}" \
    --compressed)

echo "Publishing workflow..."
OUTPUT=$(curl -skL ${HTTP_PROXY_CMD} --request PUT "https://${NSP_URL}:8546/wfm/api/v1/workflow/${WF_ID}/status" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    --data-binary '{"status":"PUBLISHED"}')

RESP_CODE=$(echo $OUTPUT | jq .response.status)
if [ "$RESP_CODE" != "200" ]; then
    echo "Publishing failed, HTTP Code $RESP_CODE"
    exit 0
fi
