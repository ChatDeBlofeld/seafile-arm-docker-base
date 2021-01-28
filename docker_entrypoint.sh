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

function waitForDb() {
    print "Waiting for db"
    export PYTHONPATH=${PYTHONPATH}:/opt/seafile/seafile-server-${VERSION}/seahub/thirdpart

    python3 - <<PYTHON_SCRIPT
import MySQLdb

while True:
    try:
        db=MySQLdb.connect(host="${MYSQL_HOST}")
    except MySQLdb.OperationalError as err:
        if err.args[0] == 1045:
            break
PYTHON_SCRIPT
}

function detectAutoMode() {
    if [ "$MYSQL_USER_PASSWD" ]
    then
        print "Auto mode detected"
        # Note: it's not possible to just call the script with "auto"
        # and the server name in argument is never set anywhere thus
        # it's basically useless.
        # So just keep it that way and wait for fixes (if they happen)
        export AUTO="auto -n useless"
    else
        print "Manual mode detected"
    fi
}

rightsManagement
waitForDb

if [ ! -d "/shared/conf" ]
then
    print "No config found. Running init script"
    detectAutoMode
    su seafile -pPc "/home/seafile/init.sh"
fi

print "Running launch script"
su seafile -pPc "/home/seafile/launch.sh"

# Stop seafile server when stopping the container
trap "{ ./seafile-server-latest/seahub.sh stop && ./seafile-server-latest/seafile.sh stop && exit 0; exit 1; }" SIGTERM

print "Waiting for SIGTERM"
tail -f /dev/null & wait
