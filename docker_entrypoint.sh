#!/bin/bash

function print() {
    echo "$(date -Iseconds) [Entrypoint] $*"
}

function quit() {
    ./seafile-server-latest/seahub.sh stop
    ./seafile-server-latest/seafile.sh stop
    exit
}

function timezoneAdjustement() {
    if [ "$TZ" ]
    then
        if [ ! -f "/usr/share/zoneinfo/$TZ" ]
        then
            print "Invalid timezone $TZ"
        else
            ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
            print "Local time set to $TZ"
        fi
    fi
}

function rightsManagement() {
    print "Checking permissions"
    if [ "$PUID" == "" ]
    then
        print "PUID not set, using current"
        PUID=$(id -u seafile)
    fi

    if [ "$PGID" == "" ]
    then
        print "GUID not set, using current"
        PGID=$(id -g seafile)
    fi

    print "Adjusting identifiers"
    groupmod -g $PGID seafile
    usermod -u $PUID seafile

    dirs=("/shared/conf" "/shared/logs" "/shared/media" "/shared/seafile-data" "/shared/seahub-data" "/shared/sqlite")
    for dir in ${dirs[@]}
    do
        if [[ -d "$dir" && ("$(stat -c %u $dir)" != $PUID || "$(stat -c %g $dir)" != $PGID) ]]
        then
            print "Changing owner for $dir"
            chown -R seafile:seafile $dir
        fi
    done
}

# Quit when receiving some signals
trap quit SIGTERM
trap quit SIGINT
trap quit SIGKILL

timezoneAdjustement
rightsManagement

if [ ! -d "/shared" ]
then
    mkdir /shared
fi

chown seafile:seafile /shared

if [ ! -f "/shared/conf/ccnet.conf" ]
then
    print "No config found. Running init script"
    su seafile -pPc "/home/seafile/init.sh"

    if [ $? != 0 ]
    then
        print "Init failed"
        exit 1
    fi
fi

print "Running launch script"
su seafile -pc "/home/seafile/launch.sh"

if [ $? != 0 ]
then
    print "Launch failed"
    exit 1
fi

print "Waiting for termination"
tail -f /dev/null & wait
