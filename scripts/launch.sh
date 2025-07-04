#!/bin/bash

set -Eeo pipefail

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
    if [ "$(echo "$SEAFILE_CONFIG" | grep -Fi [database])" ]
    then
        export SQLITE=""
        export MYSQL_HOST=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]host | cut -d'=' -f2 | xargs)
        export MYSQL_PORT=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]port | cut -d'=' -f2 | xargs)
        export MYSQL_USER=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]user | cut -d'=' -f2 | xargs)
        export MYSQL_USER_PASSWD=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]password | cut -d'=' -f2 | xargs)
        export SEAFILE_DB=$(echo "$SEAFILE_CONFIG" | grep -Fi [database]db_name | cut -d'=' -f2 | xargs)
    else
        export SQLITE=1
    fi
}

cd /opt/seafile

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
if [ ! "$SQLITE" ]
then
    print "Waiting for db"
    /home/seafile/wait_for_db.sh
fi

readCurrentRevision
if [[ $CURRENT_REVISION -lt $REVISION ]]
then
    print "New image revision, updating..."
    /home/seafile/update.sh "$CURRENT_REVISION"
    if [ $? != 0 ]; then exit 1; fi
fi

print "Launching seafile"
./seafile-server-latest/seafile.sh start
./seafile-server-latest/seahub.sh start

print "Done"
