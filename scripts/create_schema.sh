#! /usr/bin/bash

set -o allexport
source .env
set +o allexport

ROOT_DIR=$(pwd)
ORGANIZATION=$(jq -r '.tags.org' "$ROOT_DIR/config.json")
APP_NAME=$(jq -r '.tags.app' "$ROOT_DIR/config.json")
WEAVIATE_ENDPOINT=$(aws ssm get-parameters --names "/${ORGANIZATION}/${APP_NAME}/WeaviateEndpoint" | jq -r '.Parameters[0].Value')

# $WEAVIATE_ENDPOINT is empty throw error
if [ -z "$WEAVIATE_ENDPOINT" ]; then
    echo "WEAVIATE_ENDPOINT no found. Please check the SSM Parameter it and try again."
    exit 1
fi

jq -c '.classes[]' "schema.json" | while read -r class; do
    curl \
        -H "Content-Type: application/json" \
        -d "$class" \
        "$WEAVIATE_ENDPOINT/v1/schema"
    echo 
done
