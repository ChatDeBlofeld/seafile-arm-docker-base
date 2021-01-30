#!/bin/bash

function print() {
    echo "[Launch] $@"
}

print "Retrieving db location"
CONFIG_FILE="/shared/conf/ccnet.conf"
export MYSQL_HOST=$(grep -i host $CONFIG_FILE | cut -d '=' -f 2 | xargs)
export MYSQL_PORT=$(grep -i port $CONFIG_FILE | cut -d '=' -f 2 | xargs)

print "Waiting for db"
/home/seafile/wait_for_db.sh
cd /opt/seafile

if [ ! -d "./seafile-server-latest" ]
then
    print "Making symlink to latest version"
    ln -s seafile-server-$VERSION seafile-server-latest
fi

if [[ ! -f "/shared/media/version" || "$(cat /shared/media/version)" != "$VERSION" ]]
then
    print "Removing outdated media folder"
    rm -rf /shared/media

    print "Exposing new media folder in the volume"
    cp -r ./media /shared/media

    print "Properly expose avatars and custom assets"
    rm -rf /shared/media/avatars
    ln -s ../seahub-data/avatars /shared/media
    ln -s ../seahub-data/custom /shared/media
fi

if [ ! -d "./conf" ]
then
    print "Linking internal configuration and data folders with the volume"
    ln -s /shared/conf .
    ln -s /shared/ccnet .
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
    ln -s /shared/media ./seafile-server-latest/seahub
fi

print "Launching seafile"
./seafile-server-latest/seafile.sh start
./seafile-server-latest/seahub.sh start

print "Done"
