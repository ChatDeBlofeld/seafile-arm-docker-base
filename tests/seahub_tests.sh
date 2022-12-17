#!/bin/bash

set -Euo pipefail

function print() {
    echo ["$STEP"/"$STEPS"] $@
    STEP=$((STEP+1))
}

function print_log() {
    echo "$@" > $LOGS_FOLDER/$LOG_FILE
}

function authorization() {
    print "Check authorization"
    log=$(curl --no-progress-meter -d "username=$SEAFILE_ADMIN_EMAIL&password=$SEAFILE_ADMIN_PASSWORD" http://$HOST:$PORT/api2/auth-token/ 2>&1)
    token=$(echo "$log" | jq -r '.token' 2> /dev/null)

    if [[ "$token" == "" || "$token" == "null" ]]
    then
        print_log "$log"
        echo "Failed to retrieve access token"
        exit 1
    fi

    AUTHORIZATION_HEADER="Authorization: Token $token"
}

function default_library() {
    print "Check default library"
    log=$(curl --no-progress-meter -X POST -H "$AUTHORIZATION_HEADER" "http://$HOST:$PORT/api2/default-repo/" 2>&1)
    REPO_ID=$(echo "$log" | jq -r '.repo_id' 2> /dev/null)

    if [[ "$REPO_ID" == "" || "$REPO_ID" == "null" ]]
    then
        print_log "$log"
        echo "Failed to create default library"
        exit 1
    fi
}

function list_libraries() {
    print "Check list libraries"
    log=$(curl --no-progress-meter -H "$AUTHORIZATION_HEADER" -H 'Accept: application/json; indent=4' "http://$HOST:$PORT/api2/repos/" 2>&1)
    id=$(echo "$log" | jq -r '.[0].id' 2> /dev/null)

    if [[ $id != $REPO_ID || "$REPO_ID" == "null" ]]
    then
        print_log "$log"
        echo "Failed to list libraries"
        exit 1
    fi
}

function upload_link() {
    print "Check upload link"
    log=$(curl --no-progress-meter -H "$AUTHORIZATION_HEADER" "http://$HOST:$PORT/api2/repos/$REPO_ID/upload-link/" 2>&1)
    UPLOAD_URL=$(echo "$log" | sed -e 's/\"//g' 2> /dev/null)
    
    if [[ "$(echo $UPLOAD_URL | grep upload-api)" == "" ]]
    then
        print_log "$log"
        echo "Failed to retrieve upload url"
        exit 1
    fi
}

function upload_file() {
    print "Check file upload"
    FILENAME=test.txt
    FILE_CONTENT=test
    echo $FILE_CONTENT > $FILENAME
    log=$(curl --no-progress-meter -H "$AUTHORIZATION_HEADER" -F file='@test.txt' -F parent_dir='/' -F replace=1 "$UPLOAD_URL?ret-json=1" 2>&1)
    id=$(echo "$log" | jq -r '.[0].id' 2> /dev/null)
    rm $FILENAME
    
    if [[ "$id" == "" || "$REPO_ID" == "null" ]]
    then
    print_log "$log"
        echo "Failed to upload file"
        exit 1
    fi
}

function download_link() {
    print "Check download link"
    log=$(curl --no-progress-meter -H "$AUTHORIZATION_HEADER" "http://$HOST:$PORT/api2/repos/$REPO_ID/file/?p=/$FILENAME" 2>&1)
    DOWNLOAD_URL=$(echo "$log" | sed -e 's/\"//g' 2> /dev/null)
    
    if [[ "$(echo $DOWNLOAD_URL | grep 'seafhttp/files')" == "" ]]
    then
        print_log "$log"
        echo "Failed to retrieve donwload url"
        exit 1
    fi
}

function download_file() {
    print "Check file download"
    content=$(curl --no-progress-meter -H "$AUTHORIZATION_HEADER" "$DOWNLOAD_URL" 2>&1)

    if [[ "$content" != "$FILE_CONTENT" ]]
    then
        print_log "$content"
        echo "Failed to download file"
        exit 1
    fi
}

function ui_auth() {
    print "Check login with ui form"
    csrf=$(curl -s -c cookies http://$HOST:$PORT/accounts/login/ | sed -n 's/.* name=\"csrfmiddlewaretoken\" value=\"\([^"]*\).*/\1/p')
    log=$(curl -is -b cookies -d "csrfmiddlewaretoken=$csrf&login=$SEAFILE_ADMIN_EMAIL&password=$SEAFILE_ADMIN_PASSWORD" http://$HOST:$PORT/accounts/login/ 2>&1)
    success=$(echo "$log" | grep 302 2> /dev/null)

    if [[ "$success" == "" ]]
    then
        print_log "$csrf"
        print_log "$log"
        echo "Failed to log in with ui form"
        exit 1
    fi
}

function media_folder() {
    print "Check media folder accessibility"
    favicon=favicon.png
    curl --no-progress-meter http://$HOST:$PORT/media/favicons/favicon.png &> "$favicon"
    check=$(sha1sum "$favicon" | grep 71a42c2032dedfe7c6a066ed2296a8db2b120155)

    if [[ "$log" == "" ]]
    then
        print_log "$log"
        echo "Failed to access media folder"
        exit 1
    fi
}

function avatar_upload() {
    print "Check avatar upload"
    AVATAR_FILE="avatar.png"
    echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=" | base64 -d > "$AVATAR_FILE"
    log=$(curl --no-progress-meter -H "$AUTHORIZATION_HEADER" -F "avatar=@$AVATAR_FILE" -F "avatar_size=1" "http://$HOST:$PORT/api/v2.1/user-avatar/" 2>&1)
    AVATAR_URL=$(echo "$log" | jq -r '.avatar_url' 2> /dev/null)

    if [[ $AVATAR_URL == "" || "$AVATAR_URL" == "null" ]]
    then
        print_log "$log"
        echo "Failed to upload avatar"
        exit 1
    fi
}

function avatar_folder() {
    print "Check avatar folder accessibility"
    file="$AVATAR_FILE".1
    curl --no-progress-meter $AVATAR_URL &> "$file"
    cmp -s "$AVATAR_FILE" "$file"

    if [[ "$?" != "0" ]]
    then
        print_log "$log"
        echo "Failed to access avatar folder"
        exit 1
    fi
}

echo "-------- SEAHUB TESTS --------"

tests=(authorization default_library list_libraries upload_link upload_file download_link download_file ui_auth media_folder avatar_upload avatar_folder)
LOG_FILE=seahub_logs-$(date +"%s")
STEP=1
STEPS=${#tests[@]}

for test in "${!tests[@]}"
do
    ${tests[$test]}
done
