#!/bin/bash

function print() {
    echo "$(date -Iseconds) [Launch] $*"
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
    else
        export SQLITE=1
    fi
}

cd /opt/seafile

if [ ! -d "./seafile-server-latest" ]
then
    print "Making symlink to latest version"
    ln -s seafile-server-$SEAFILE_SERVER_VERSION seafile-server-latest
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

if [ ! -d "./conf" ]
then
    print "Linking internal configuration and data folders with the volume"
    ln -s /shared/conf .
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
    ln -s /shared/media ./seafile-server-latest/seahub
    if [ -d "/shared/sqlite" ]
    then 
        ln -s /shared/sqlite ./ccnet
        ln -s /shared/sqlite/seahub.db .
    else
        mkdir ccnet # Totally useless but still needed for the server to launch
    fi
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
    /home/seafile/update.sh $CURRENT_REVISION
    if [ $? != 0 ]; then exit 1; fi
fi

print "Launching seafile"
./seafile-server-latest/seafile.sh start
./seafile-server-latest/seahub.sh start

print "Done"
