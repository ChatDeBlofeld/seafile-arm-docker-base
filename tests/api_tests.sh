#!/bin/bash

set -Euo pipefail

function print() {
    echo ["$STEP"/"$STEPS"] $@
    STEP=$((STEP+1))
}

function authorization() {
    print "Check authorization"
    token=$(curl -sd "username=$SEAFILE_ADMIN_EMAIL&password=$SEAFILE_ADMIN_PASSWORD" http://$HOST:$PORT/api2/auth-token/ | jq -r '.token')

    if [[ "$token" == "" || "$token" == "null" ]]
    then
        echo "Failed to retrieve access token"
        exit 1
    fi

    AUTHORIZATION_HEADER="Authorization: Token $token"
}

function default_library() {
    print "Check default library"
    REPO_ID=$(curl -s -X POST -H "$AUTHORIZATION_HEADER" "http://$HOST:$PORT/api2/default-repo/" | jq -r '.repo_id')

    if [[ "$REPO_ID" == "" ]]
    then
        echo "Failed to create default library"
        exit 1
    fi
}

function list_libraries() {
    print "Check list libraries"
    id=$(curl -s -H "$AUTHORIZATION_HEADER" -H 'Accept: application/json; indent=4' "http://$HOST:$PORT/api2/repos/" | jq -r '.[0].id')

    if [[ $id != $REPO_ID ]]
    then
        echo "Failed to list libraries"
        exit 1
    fi
}

echo "------ API TESTS ------"

tests=(authorization default_library list_libraries)
STEP=1
STEPS=${#tests[@]}

for test in "${!tests[@]}"
do
    ${tests[$test]}
done
