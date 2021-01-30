#!/bin/bash

function print() {
    echo "[Init] $@"
}

function detectAutoMode() {
    if [ "$MYSQL_USER_PASSWD" ]
    then
        print "Auto mode detected"
        # Note: it's not possible to just call the script with "auto"
        # and the server name in argument is never set anywhere thus
        # it's basically useless.
        # So just keep it that way and wait for fixes (if they happen)
        AUTO="auto -n useless"
    else
        print "Manual mode detected"
    fi
}

print "Setting default environment"
if [ ! "$SERVER_IP" ]; then export SERVER_IP=127.0.0.1; fi
if [ "$ENABLE_TLS" ]; then export ENABLE_TLS="s"; fi
if [ ! "$CONTAINER_IP" ]; then export CONTAINER_IP=127.0.0.1; fi
if [ ! "$MYSQL_USER" ]; then export MYSQL_USER=seafile; fi
if [ ! "$MYSQL_USER_HOST" ]; then export MYSQL_USER_HOST="%"; fi

print "Waiting for db"
/home/seafile/wait_for_db.sh

detectAutoMode
cd /opt/seafile

print "Exposing media folder in the volume"
cp -r ./media /shared/media
ln -s /shared/media ./seafile-server-$VERSION/seahub

print "Running installation script"
LOGFILE=./install.log
./seafile-server-$VERSION/setup-seafile-mysql.sh $AUTO | tee $LOGFILE

# Handle db starting twice at init edge case 
if [[ "$AUTO" && "$(grep -Pi '(failed)|(error)' $LOGFILE)" ]]
then
    print "Installation failed. Maybe the db wasn't really ready?"

    print "Cleaning failed configuration"
    rm -rf ./conf
    rm -rf ./ccnet

    print "Waiting for db... again"
    /home/seafile/wait_for_db.sh

    print "Retrying install"
    ./seafile-server-$VERSION/setup-seafile-mysql.sh $AUTO | tee $LOGFILE
fi

if [ "$(grep -Pi '(failed)|(error)|(missing)' $LOGFILE)" ]
then
    print "Something went wrong"
    exit 1
fi

print "Properly expose avatars and custom assets"
rm -rf /shared/media/avatars
ln -s ../seahub-data/avatars /shared/media
ln -s ../seahub-data/custom /shared/media

print "Exposing configuration and data"
mv ./conf /shared/conf
mv ./ccnet /shared/ccnet
mv ./seafile-data /shared/seafile-data
mv ./seahub-data /shared/seahub-data
mkdir /shared/logs
mkdir /shared/seahub-data/custom

if [ ! -d "./seafile-server-latest" ]
then
    print "Making symlink to latest version"
    ln -s seafile-server-$VERSION seafile-server-latest
fi

if [ ! -d "./conf" ]
then
    print "Linking internal configuration and data folders with the volume"
    ln -s /shared/conf .
    ln -s /shared/ccnet .
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
fi

if [ "$AUTO" ]
then
    print "Setting admin credentials"
    echo "{\"email\":\"$SEAFILE_ADMIN_EMAIL\", \"password\":\"$SEAFILE_ADMIN_PASSWORD\"}" > ./conf/admin.txt
fi

print "Writing configuration"
/home/seafile/write_config.sh

print "Done"
