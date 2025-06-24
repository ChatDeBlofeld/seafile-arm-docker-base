#!/bin/bash

set -Eeo pipefail

CONFIG_DIR="/shared/conf"
CCNET_CONFIG_FILE="$CONFIG_DIR/ccnet.conf"
GUNICORN_CONFIG_FILE="$CONFIG_DIR/gunicorn.conf.py"
SEAHUB_CONFIG_FILE="$CONFIG_DIR/seahub_settings.py"
SEAFILE_CONFIG_FILE="$CONFIG_DIR/seafile.conf"
WEBDAV_CONFIG_FILE="$CONFIG_DIR/seafdav.conf"
SEAFEVENTS_CONFIG_FILE="$CONFIG_DIR/seafevents.conf"

function writeCcnetConfig() {
    if [ "$HTTPS_SUFFIX" ]
    then
        echo "USE_X_FORWARDED_HOST = True" >> $CCNET_CONFIG_FILE
        echo "SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')" >> $CCNET_CONFIG_FILE
    fi
}

function writeGunicornSettings() {
    sed -ni '/8000/!p' $GUNICORN_CONFIG_FILE
    echo "bind = \"0.0.0.0:${SEAHUB_PORT}\"" >> $GUNICORN_CONFIG_FILE
}

function writeSeahubConfiguration() {
    sed -ni "/SERVICE_URL/!p" $SEAHUB_CONFIG_FILE
    echo "SERVICE_URL = \"http${HTTPS_SUFFIX}://${SERVER_IP}\""                 >> $SEAHUB_CONFIG_FILE
    echo "FILE_SERVER_ROOT = \"http${HTTPS_SUFFIX}://${SERVER_IP}/seafhttp\""   >> $SEAHUB_CONFIG_FILE
    echo "CSRF_TRUSTED_ORIGINS = [\"http${HTTPS_SUFFIX}://${SERVER_IP}\"]"      >> $SEAHUB_CONFIG_FILE

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

function writeSeafeventsConfiguration() {
    # Rewrites everything to disable events by default and, especially,
    # disable pro features that are not available in community edition

    echo "[DATABASE]"                       >  $SEAFEVENTS_CONFIG_FILE
    echo "type = mysql"                     >> $SEAFEVENTS_CONFIG_FILE
    echo "host = $MYSQL_HOST"               >> $SEAFEVENTS_CONFIG_FILE
    echo "port = $MYSQL_PORT"               >> $SEAFEVENTS_CONFIG_FILE
    echo "username = $MYSQL_USER"           >> $SEAFEVENTS_CONFIG_FILE
    # FIXME: Will fail if user is root, drop this possibility
    echo "password = $MYSQL_USER_PASSWD"    >> $SEAFEVENTS_CONFIG_FILE
    echo "name = $SEAHUB_DB"                >> $SEAFEVENTS_CONFIG_FILE

    echo "[SEAHUB EMAIL]"                   >> $SEAFEVENTS_CONFIG_FILE
    echo "enabled = false"                  >> $SEAFEVENTS_CONFIG_FILE
    echo "interval = 30m"                   >> $SEAFEVENTS_CONFIG_FILE

    echo "[STATISTICS]"                     >> $SEAFEVENTS_CONFIG_FILE
    echo "enabled = false"                  >> $SEAFEVENTS_CONFIG_FILE
}

cd /opt/seafile

echo "Writing ccnet configuration"
writeCcnetConfig

echo "Writing gunicorn configuration"
writeGunicornSettings

echo "Writing seahub configuration"
writeSeahubConfiguration

echo "Writing seafile configuration"
writeSeafileConfiguration

echo "Writing seafevents configuration"
writeSeafeventsConfiguration

if [ "$WEBDAV" = "1" ]; then
    echo "Writing webdav configuration"
    writeWebdavConfiguration
fi