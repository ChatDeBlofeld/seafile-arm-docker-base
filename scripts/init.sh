#!/bin/bash

cd /opt/seafile

if [ ! "$MYSQL_USER" ]; then export MYSQL_USER=seafile; fi
if [ ! "$MYSQL_USER_HOST" ]; then export MYSQL_USER_HOST="%"; fi

# Expose media folder in the volume
cp -r ./media /shared/media
ln -s /shared/media ./seafile-server-$VERSION/seahub

# Run installation script
./seafile-server-$VERSION/setup-seafile-mysql.sh $AUTO

# Properly expose avatars and custom assets
rm -rf /shared/media/avatars
ln -s ../seahub-data/avatars /shared/media
ln -s ../seahub-data/custom /shared/media

# Expose configuration and data
mv ./conf /shared/conf
mv ./ccnet /shared/ccnet
mv ./seafile-data /shared/seafile-data
mv ./seahub-data /shared/seahub-data
mkdir /shared/logs
mkdir /shared/seahub-data/custom

if [ ! -d "./seafile-server-latest" ]
then
    ln -s seafile-server-$VERSION seafile-server-latest
fi

if [ ! -d "./conf" ]
then
    # Link internal configuration and data folders with the volume
    ln -s /shared/conf .
    ln -s /shared/ccnet .
    ln -s /shared/seafile-data .
    ln -s /shared/seahub-data .
    ln -s /shared/logs .
fi

# Credentials in this file will be read at startup
echo '{"email":"$SEAFILE_ADMIN_EMAIL", "password":"$SEAFILE_ADMIN_PASSWORD"}' > ./conf/admin.txt

# Needed for admin account set up
./seafile-server-latest/seafile.sh start
./seafile-server-latest/seahub.sh start

./seafile-server-latest/seahub.sh stop
./seafile-server-latest/seafile.sh stop
