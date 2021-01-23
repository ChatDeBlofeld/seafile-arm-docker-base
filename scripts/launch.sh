#!/bin/bash

cd /opt/seafile

if [ ! -d "/shared/conf" ]
then
    echo "No configuration available. Please run init.sh first."
    exit 1
fi

if [ ! -d "./seafile-server-latest" ]
then
    ln -s seafile-server-$VERSION seafile-server-latest
fi

if [[ ! -f "/shared/media/version" || "$(cat /shared/media/version)" != "$VERSION" ]]
then
    # Remove outdated media folder
    rm -rf /shared/media

    # Expose new media folder in the volume
    cp -r ./media /shared/media

    # Properly expose avatars and custom assets
    rm -rf /shared/media/avatars
    ln -s ../seahub-data/avatars /shared/media
    ln -s ../seahub-data/custom /shared/media
fi

if [ ! -d "./conf" ]
then
    # Link internal configuration and data folders with the volume
    ln -s /shared/conf .
    ln -s /shared/ccnet .
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
    ln -s /shared/media ./seafile-server-latest/seahub
fi

./seafile-server-latest/seafile.sh start
./seafile-server-latest/seahub.sh start

# Stop seafile server when stopping the container
trap "{ ./seafile-server-latest/seahub.sh stop && ./seafile-server-latest/seafile.sh stop && exit 0; exit 1; }" SIGTERM

tail -f /dev/null & wait
