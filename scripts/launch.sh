#!/bin/bash

set -Eeo pipefail

. /home/seafile/include.sh

function print() {
    echo "$(date +"%F %T") [Launch] $*"
}

function readCurrentRevision() {
    CURRENT_REVISION=0
    if [ -f "/shared/conf/revision" ]
    then
        CURRENT_REVISION=$(cat /shared/conf/revision)
    fi
}

function readSGBD() {
    SEAFILE_CONFIG="$(awk '/\[/{prefix=$0; next} $1{print prefix $0}' /shared/conf/seafile.conf)"
    export MYSQL_HOST=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]host | cut -d'=' -f2 | xargs)
    export MYSQL_PORT=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]port | cut -d'=' -f2 | xargs)
    export MYSQL_USER=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]user | cut -d'=' -f2 | xargs)
    export MYSQL_USER_PASSWD=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]password | cut -d'=' -f2 | xargs)
    export SEAFILE_DB=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]db_name | cut -d'=' -f2 | xargs)
}

cd /opt/seafile

bind_volumes

if [ -f "/shared/conf/seafevents.conf" ]
then
    print "This image does not support seafevents, please remove or rename seafevents.conf"
    exit 1
fi

if [[ ! -f "/shared/media/version" || "$(cat /shared/media/version)" != "$SEAFILE_SERVER_VERSION" ]]
then
    print "Removing outdated media folder"
    rm -rf /shared/media/*

    print "Exposing new media folder in the volume"
    cp -r ./media /shared/

    print "Properly expose avatars and custom assets"
    rm -rf /shared/media/avatars
    ln -s ../seahub-data/avatars /shared/media
    ln -s ../seahub-data/custom /shared/media
fi

readSGBD
NOTIFICATION_SERVER_ENABLED=$(awk -F '=' '/\[notification\]/{a=1}a==1&&$1~/enabled/{print $2;exit}' /shared/conf/seafile.conf | sed -E "s/[[:space:]]//g")

print "Waiting for db"
/home/seafile/wait_for_db.sh

readCurrentRevision
if [[ $CURRENT_REVISION -lt $REVISION ]]
then
    print "New image revision, updating..."
    /home/seafile/update.sh "$CURRENT_REVISION"
    if [ $? != 0 ]; then exit 1; fi
fi

load_seafile_env

if [ "$NOTIFICATION_SERVER_ENABLED" = "true" ]
then
    print "Launching notification server"
    ./seafile-server-latest/seafile/bin/notification-server -c /shared/conf -l /shared/logs/notification-server.log &
    sleep 1
fi

print "Launching seafile"
./seafile-server-latest/seafile.sh start
./seafile-server-latest/seahub.sh start

print "Done"
