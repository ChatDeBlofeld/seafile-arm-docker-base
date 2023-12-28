#!/bin/bash

set -Eeo pipefail

function print() {
    echo "$(date +"%F %T") [Bind] $*"
}

if [ ! -d "./seafile-server-latest" ]
then
    print "Making symlink to latest version"
    ln -s seafile-server-$SEAFILE_SERVER_VERSION seafile-server-latest
fi

if [ ! -L "./seafile-server-latest/seahub/media" ]
then
    print "Binding media folder with the volume"
    ln -s /shared/media ./seafile-server-latest/seahub
fi

if [ ! -d "./conf" ]
then
    print "Binding internal configuration and data folders with the volume"
    ln -s /shared/conf .
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
    if [ ! -d "./ccnet" ]
    then
        mkdir ccnet # Totally useless but still needed for the server to launch
    fi
fi
