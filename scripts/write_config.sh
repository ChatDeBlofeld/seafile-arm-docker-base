#!/bin/bash

set -Eeo pipefail

CONFIG_DIR="/shared/conf"
SEAFILE_ENV_FILE="$CONFIG_DIR/seafile.env"
GUNICORN_CONFIG_FILE="$CONFIG_DIR/gunicorn.conf.py"
SEAHUB_CONFIG_FILE="$CONFIG_DIR/seahub_settings.py"
SEAFILE_CONFIG_FILE="$CONFIG_DIR/seafile.conf"
WEBDAV_CONFIG_FILE="$CONFIG_DIR/seafdav.conf"
SEAFEVENTS_CONFIG_FILE="$CONFIG_DIR/seafevents.conf"

function writeSeafileEnv() {
    echo "# This file is the equivalent of the .env file mentioned in the Seafile documentation since version 12."   > $SEAFILE_ENV_FILE
    echo "# It is generated for compatibility and smooth upgrades."                                                 >> $SEAFILE_ENV_FILE
    echo "# Remove it if you wan't to set the environment variables directly from docker (e.g. in a compose file)." >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_USER=${SEAFILE_MYSQL_DB_USER}"                                                           >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_PASSWORD=${SEAFILE_MYSQL_DB_PASSWORD}"                                                   >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_CCNET_DB_NAME=${SEAFILE_MYSQL_DB_CCNET_DB_NAME}"                                         >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=${SEAFILE_MYSQL_DB_SEAFILE_DB_NAME}"                                     >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=${SEAFILE_MYSQL_DB_SEAHUB_DB_NAME}"                                       >> $SEAFILE_ENV_FILE
    echo "JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY}"                                                                       >> $SEAFILE_ENV_FILE
    echo "SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}"                                                       >> $SEAFILE_ENV_FILE
    echo "SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL}"                                                       >> $SEAFILE_ENV_FILE
    echo "TIME_ZONE=${TIME_ZONE}"                                                                                   >> $SEAFILE_ENV_FILE
}

function writeGunicornSettings() {
    sed -ni '/8000/!p' $GUNICORN_CONFIG_FILE
    echo "bind = \"0.0.0.0:${SEAHUB_PORT}\"" >> $GUNICORN_CONFIG_FILE
}

function writeSeahubConfiguration() {
    sed -ni "/SERVICE_URL/!p" $SEAHUB_CONFIG_FILE
    echo "SERVICE_URL = \"${HTTP_PROTO}://${SERVER_IP}\""                 >> $SEAHUB_CONFIG_FILE
    echo "FILE_SERVER_ROOT = \"${HTTP_PROTO}://${SERVER_IP}/seafhttp\""   >> $SEAHUB_CONFIG_FILE
    echo "CSRF_TRUSTED_ORIGINS = [\"${HTTP_PROTO}://${SERVER_IP}\"]"      >> $SEAHUB_CONFIG_FILE

    if [ "$MEMCACHED_HOST" ]
    then
        echo "CACHES = {"                                                   >> $SEAHUB_CONFIG_FILE
        echo "    'default': {"                                             >> $SEAHUB_CONFIG_FILE
        echo "        'BACKEND': 'django_pylibmc.memcached.PyLibMCCache',"  >> $SEAHUB_CONFIG_FILE
        echo "        'LOCATION': '$MEMCACHED_HOST',"                       >> $SEAHUB_CONFIG_FILE
        echo "    },"                                                       >> $SEAHUB_CONFIG_FILE
        echo "}"                                                            >> $SEAHUB_CONFIG_FILE
    fi
}

function writeSeafileConfiguration() {
    if [ "$NOTIFICATION_SERVER" = "1" ]
    then

        while IFS= read -r line; do
            if [[ "$line" =~ ^(;|#).*$ ]]; then
                echo "$line" >> "$SEAFILE_CONFIG_FILE.new"
                continue
            elif [[ "$line" =~ ^\[.*\]$ ]]; then
                section=$(echo $line | sed -n 's#\[\(.*\)\]#\1#p')
            else
                key=$(echo $line | cut -d= -f 1 | xargs)
            fi

            if [ "$section" = "notification" ]; then
                if [ "$key" = "enabled" ]; then
                    echo "enabled = true" >> "$SEAFILE_CONFIG_FILE.new"
                    continue
                elif [ "$key" = "host" ]; then
                    echo "host = 0.0.0.0" >> "$SEAFILE_CONFIG_FILE.new"
                    continue
                fi
            fi
                
            echo "$line" >> "$SEAFILE_CONFIG_FILE.new"
        done < "$SEAFILE_CONFIG_FILE"

        rm "$SEAFILE_CONFIG_FILE"
        mv "$SEAFILE_CONFIG_FILE.new" "$SEAFILE_CONFIG_FILE"
    fi
}

function writeWebdavConfiguration() {
    echo "[WEBDAV]"                 >  $WEBDAV_CONFIG_FILE
    echo "enabled = true"           >> $WEBDAV_CONFIG_FILE
    echo "host = seafile"           >> $WEBDAV_CONFIG_FILE
    echo "port = 8080"              >> $WEBDAV_CONFIG_FILE
    echo "fastcgi = false"          >> $WEBDAV_CONFIG_FILE
    echo "share_name = /seafdav"    >> $WEBDAV_CONFIG_FILE
}

cd /opt/seafile

echo "Writing Seafile environment"
writeSeafileEnv

echo "Writing gunicorn configuration"
writeGunicornSettings

echo "Writing seahub configuration"
writeSeahubConfiguration

echo "Writing seafile configuration"
writeSeafileConfiguration

if [ "$WEBDAV" = "1" ]; then
    echo "Writing webdav configuration"
    writeWebdavConfiguration
fi