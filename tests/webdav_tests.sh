#!/bin/bash

set -Euo pipefail

function print() {
    echo ["$STEP"/"$STEPS"] $@
    STEP=$((STEP+1))
}

function print_log() {
    echo "$@" > $LOGS_FOLDER/$LOG_FILE
}

function access() {
    print "Check access"
    log=$(curl --no-progress-meter --user "$SEAFILE_ADMIN_EMAIL:$SEAFILE_ADMIN_PASSWORD" -X PROPFIND -H "Depth: 1" http://$HOST:$PORT/seafdav 2>&1)

    if [ "$(echo $log | grep '200 OK')" = "" ] 
    then
        print_log "$log"
        echo "Failed to access webdav"
        exit 1
    fi

    LIBRARY=$(echo $log | sed -n 's#.*<D:href>/seafdav/\([^/]*\).*#\1#p')
}

function upload_file() {
    print "Check file upload"
    FILENAME=test-webdav.txt
    FILE_CONTENT=test
    echo $FILE_CONTENT > $FILENAME
    log=$(curl --no-progress-meter --user "$SEAFILE_ADMIN_EMAIL:$SEAFILE_ADMIN_PASSWORD" -T "$FILENAME" http://$HOST:$PORT/seafdav/$LIBRARY/$FILENAME 2>&1)
    success=$(echo "$log" | grep 201 2> /dev/null)
    
    if [ "$success" = "" ]
    then
        print_log "$log"
        echo "Failed to upload file"
        exit 1
    fi
}

function download_file() {
    print "Check file download"
    content=$(curl --no-progress-meter --user "$SEAFILE_ADMIN_EMAIL:$SEAFILE_ADMIN_PASSWORD" -X GET http://$HOST:$PORT/seafdav/$LIBRARY/$FILENAME 2>&1)

    if [[ "$content" != "$FILE_CONTENT" ]]
    then
        print_log "$content"
        echo "Failed to download file"
        exit 1
    fi
}

tests=(access upload_file download_file)
LOG_FILE=$(date +"%s")-webdav.log
STEP=1
STEPS=${#tests[@]}

for test in "${!tests[@]}"
do
    ${tests[$test]}
done