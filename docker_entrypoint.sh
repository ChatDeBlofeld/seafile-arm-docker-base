#!/bin/bash

function print() {
    echo "[Entrypoint] $@"
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

    dirs=("/home/seafile" "/opt/seafile" "/shared")
    for dir in ${dirs[@]}
    do
        if [[ "$(stat -c %u $dir)" != $PUID || "$(stat -c %g $dir)" != $PGID ]]
        then
            print "Changing owner for $dir"
            chown -R seafile:seafile $dir
        fi
    done
}

# Export database default location
if [ ! "$MYSQL_HOST" ]; then export MYSQL_HOST=127.0.0.1; fi
if [ ! "$MYSQL_PORT" ]; then export MYSQL_PORT=3306; fi

rightsManagement

if [ ! -d "/shared/conf" ]
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
su seafile -pPc "/home/seafile/launch.sh"

# Stop seafile server when stopping the container
trap "{ ./seafile-server-latest/seahub.sh stop && ./seafile-server-latest/seafile.sh stop && exit 0; exit 1; }" SIGTERM

print "Waiting for SIGTERM"
tail -f /dev/null & wait
