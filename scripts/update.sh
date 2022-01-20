#!/bin/bash

set -Eeuo pipefail

function print() {
    echo "$(date -Iseconds) [Update] $@"
}

function update_db() {
    if ! python3 ${INSTALLPATH}/upgrade/db_update_helper.py $1
    then
        print "Failed to update database"
        exit 1
    fi
}

CURRENT_REVISION=$1
TOPDIR=/opt/seafile
INSTALLPATH=${TOPDIR}/seafile-server-latest
export CCNET_CONF_DIR=${TOPDIR}/ccnet
export SEAFILE_CONF_DIR=${TOPDIR}/seafile-data
export SEAFILE_CENTRAL_CONF_DIR=${TOPDIR}/conf
export PYTHONPATH=${INSTALLPATH}/seafile/lib/python3.6/site-packages:${INSTALLPATH}/seafile/lib64/python3.6/site-packages:${INSTALLPATH}/seahub:${INSTALLPATH}/seahub/thirdpart:$PYTHONPATH

if [ $CURRENT_REVISION -lt 1 ]; then
    if [ ! "$SQLITE" ]; then
        print "Update database to Seafile 8 scheme"
        update_db 8.0.0
    fi
fi

if [ $CURRENT_REVISION -lt 2 ]; then
    print "Update database to Seafile 9 scheme"
    update_db 9.0.0

    print "Move SERVICE_URL to seahub_settings.py"
    service_url=`awk -F '=' '/\[General\]/{a=1}a==1&&$1~/SERVICE_URL/{print $2;exit}' ${SEAFILE_CENTRAL_CONF_DIR}/ccnet.conf`
    service_url=$(echo $service_url)
    echo "SERVICE_URL = '${service_url}'">>${SEAFILE_CENTRAL_CONF_DIR}/seahub_settings.py
fi


echo $REVISION > "/shared/conf/revision"
print "Done!"
