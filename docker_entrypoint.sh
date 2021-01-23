#!/bin/bash

if [ "$PUID" == "" ]
then
    PUID=$(id -u seafile)
fi

if [ "$PGID" == "" ]
then
    PGID=$(id -g seafile)
fi

groupmod -g $PGID seafile
usermod -u $PUID seafile

dirs=("/home/seafile" "/opt/seafile" "/shared")
for dir in ${dirs[@]}
do
    if [[ "$(stat -c %u $dir)" != $PUID || "$(stat -c %g $dir)" != $PGID ]]
    then
        chown -R seafile:seafile $dir
    fi
done

su seafile -pPc /home/seafile/$1.sh
