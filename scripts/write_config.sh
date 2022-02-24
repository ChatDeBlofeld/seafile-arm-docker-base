#!/bin/bash

set -Eeo pipefail

CONFIG_DIR="./conf"
CCNET_CONFIG_FILE="$CONFIG_DIR/ccnet.conf"
GUNICORN_CONFIG_FILE="$CONFIG_DIR/gunicorn.conf.py"
SEAHUB_CONFIG_FILE="$CONFIG_DIR/seahub_settings.py"

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
    echo "SERVICE_URL = \"http${HTTPS_SUFFIX}://${SERVER_IP}\"" >> $SEAHUB_CONFIG_FILE
    echo "FILE_SERVER_ROOT = \"http${HTTPS_SUFFIX}://${SERVER_IP}/seafhttp\"" >> $SEAHUB_CONFIG_FILE
}

cd /opt/seafile

echo "Writing ccnet configuration"
writeCcnetConfig

echo "Writing gunicorn configuration"
writeGunicornSettings

echo "Writing seahub configuration"
writeSeahubConfiguration
