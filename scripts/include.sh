#!/bin/false

# This file is sourced by other scripts, do not run it directly.
# Scripts that source this file should provide the following functions:
# - print

function bind_volumes() {
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
    fi
}

function load_seafile_env() {
    if [ -f "/shared/conf/seafile.env" ]
    then
        print "Loading environment variables from seafile.env"
        set -o allexport
        . /shared/conf/seafile.env
        set +o allexport
    fi
}