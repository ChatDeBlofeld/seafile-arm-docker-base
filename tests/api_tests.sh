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
        RETURN=1
    fi
}

function upload_link() {
    print "Check upload link"
    UPLOAD_URL=$(curl -s -H "$AUTHORIZATION_HEADER" "http://$HOST:$PORT/api2/repos/$REPO_ID/upload-link/" | sed -e 's/\"//g')
    
    if [[ "$(echo $UPLOAD_URL | grep upload-api)" == "" ]]
    then
        echo "Failed to retrieve upload url"
        exit 1
    fi
}

function upload_file() {
    print "Check file upload"
    echo $FILE_CONTENT > $FILENAME
    id=$(curl -s -H "$AUTHORIZATION_HEADER" -F file='@test.txt' -F parent_dir='/' -F replace=1 "$UPLOAD_URL?ret-json=1" | jq -r '.[0].id')
    rm $FILENAME
    
    if [[ "$id" == "" ]]
    then
        echo "Failed to upload file"
        exit 1
    fi
}

function download_link() {
    print "Check download link"
    DOWNLOAD_URL=$(curl -s -H "$AUTHORIZATION_HEADER" "http://$HOST:$PORT/api2/repos/$REPO_ID/file/?p=/$FILENAME" | sed -e 's/\"//g')
    
    if [[ "$(echo $DOWNLOAD_URL | grep 'seafhttp/files')" == "" ]]
    then
        echo "Failed to retrieve donwload url"
        exit 1
    fi
}

function download_file() {
    print "Check file download"
    content=$(curl -s -H "$AUTHORIZATION_HEADER" "$DOWNLOAD_URL")

    if [[ "$content" != "$FILE_CONTENT" ]]
    then
        echo "Failed to download file"
        RETURN=1
    fi
}

echo "------ API TESTS ------"

tests=(authorization default_library list_libraries upload_link upload_file download_link download_file)
STEP=1
STEPS=${#tests[@]}

FILENAME=test.txt
FILE_CONTENT=test

RETURN=0
for test in "${!tests[@]}"
do
    ${tests[$test]}
done

exit $RETURN
