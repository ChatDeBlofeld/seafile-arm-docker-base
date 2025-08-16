#!/bin/bash

set -Eeo pipefail

function print() {
    echo "$(date +"%F %T") [Update] $*"
}

function update_db() {
    if ! python3 "${INSTALLPATH}"/upgrade/db_update_helper.py "$1"
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
SEAFILE_ENV_FILE="$SEAFILE_CENTRAL_CONF_DIR/seafile.env"
CCNET_CONFIG_FILE="$CCNET_CONF_DIR/ccnet.conf"
SEAFILE_CONFIG_FILE="$SEAFILE_CONF_DIR/seafile.conf"
SEAHUB_CONFIG_FILE="$SEAFILE_CENTRAL_CONF_DIR/seahub_settings.py"
GUNICORN_CONFIG_FILE="$SEAFILE_CENTRAL_CONF_DIR/gunicorn.conf.py"
WEBDAV_CONFIG_FILE="$SEAFILE_CENTRAL_CONF_DIR/seafdav.conf"
SEAFEVENTS_CONFIG_FILE="$SEAFILE_CENTRAL_CONF_DIR/seafevents.conf"

if [ "$SQLITE" ]; then
    print "------------------------------------------------------------------------"
    print "                    SQLITE SUPPORT HAS BEEN REMOVED"
    print "See deprecation announcement:"
    print "   https://forum.seafile.com/t/major-changes-in-seafile-version-11-0/18474#deprecating-sqlite-database-support-5"
    print "Please follow migration guide:"
    print "   https://github.com/ChatDeBlofeld/seafile-arm-docker-base/blob/v11.0.13/SQLITE_2_MYSQL.md"
    print ""
    print "If you're already using MariaDB or MySQL, please clean the SQLITE environment variable in your compose file or Docker run command."
    print "------------------------------------------------------------------------"
    exit 1
fi

if [ "$CURRENT_REVISION" -lt 1 ]; then
    print "Update database to Seafile 8 scheme"
    update_db 8.0.0
fi

if [ "$CURRENT_REVISION" -lt 2 ]; then
    print "Update database to Seafile 9 scheme"
    update_db 9.0.0

    print "Move SERVICE_URL to seahub_settings.py"
    service_url=$(awk -F '=' '/\[General\]/{a=1}a==1&&$1~/SERVICE_URL/{print $2;exit}' ${CCNET_CONFIG_FILE})
    service_url=$(echo $service_url)
    echo "SERVICE_URL = '${service_url}'">>${SEAHUB_CONFIG_FILE}
fi

if [ "$CURRENT_REVISION" -lt 13 ]; then
    print "Update database to Seafile 10 scheme"
    update_db 10.0.0
fi

function readSeahubConfig() {
    SEAHUB_DB="$(awk -F '=' '/\[Database\]/{a=1}a==1&&$1~/NAME/{print $2;exit}' ${SEAHUB_CONFIG_FILE})"
    SERVICE_URL="$(awk -F '=' '/SERVICE_URL/{print $2;exit}' seahub_settings.py | sed "s/[\" ']//g" | sed -E "s/\/?$//g")"
    HTTP_PROTO="$(echo "$SERVICE_URL" | cut -d':' -f1)"
    SERVER_IP="$(echo "$SERVICE_URL" | sed "s/${HTTP_PROTO}:\/\///g" | cut -d'/' -f1)"
}

if [ "$CURRENT_REVISION" -lt 14 ]; then
    readSeahubConfig
    # This just makes absolutely no sense, why isn't this fixed upstream!?
    # https://forum.seafile.com/t/seafile-community-edition-11-0-3-and-seadoc-0-4-are-now-ready/19017/5
    print "Fix database... !?"
    python3 - <<PYTHON_SCRIPT
import MySQLdb
from time import sleep

db=MySQLdb.connect(host="${MYSQL_HOST}", port=${MYSQL_PORT}, user="$MYSQL_USER",
                   password="$MYSQL_USER_PASSWD", database="$SEAHUB_DB")
cursor=db.cursor()
cursor.execute("ALTER TABLE org_saml_config ADD COLUMN (domain varchar(255) UNIQUE DEFAULT NULL);")
db.commit()
db.close()
PYTHON_SCRIPT

    print "Update database to Seafile 11 scheme"
    update_db 11.0.0

    print "Write minimal CSRF config"
    url=$(cat "$SEAHUB_CONFIG_FILE" | grep SERVICE_URL | cut -d"=" -f2)
    echo "CSRF_TRUSTED_ORIGINS = [$url]" >> "$SEAHUB_CONFIG_FILE"

    print "Generate seafevents.conf"
    python3 $INSTALLPATH/pro/pro.py setup --mysql --mysql_host "$MYSQL_HOST" --mysql_port "$MYSQL_PORT" --mysql_user "$MYSQL_USER" --mysql_password "$MYSQL_USER_PASSWD" --mysql_db "$SEAHUB_DB"
    echo "[DATABASE]"                       >  $SEAFEVENTS_CONFIG_FILE
    echo "type = mysql"                     >> $SEAFEVENTS_CONFIG_FILE
    echo "host = $MYSQL_HOST"               >> $SEAFEVENTS_CONFIG_FILE
    echo "port = $MYSQL_PORT"               >> $SEAFEVENTS_CONFIG_FILE
    echo "username = $MYSQL_USER"           >> $SEAFEVENTS_CONFIG_FILE
    echo "password = $MYSQL_USER_PASSWD"    >> $SEAFEVENTS_CONFIG_FILE
    echo "name = $SEAHUB_DB"                >> $SEAFEVENTS_CONFIG_FILE
    echo "[SEAHUB EMAIL]"                   >> $SEAFEVENTS_CONFIG_FILE
    echo "enabled = false"                  >> $SEAFEVENTS_CONFIG_FILE
    echo "interval = 30m"                   >> $SEAFEVENTS_CONFIG_FILE
    echo "[STATISTICS]"                     >> $SEAFEVENTS_CONFIG_FILE
    echo "enabled = false"                  >> $SEAFEVENTS_CONFIG_FILE
fi

if [ "$CURRENT_REVISION" -lt 15 ]; then
    readSeahubConfig
    ccnet_db=$(awk -F '=' '/\[Database\]/{a=1}a==1&&$1~/DB/{print $2;exit}' ${CCNET_CONFIG_FILE})

    echo "# This file is the equivalent of the .env file mentioned in the Seafile documentation since version 12."   > $SEAFILE_ENV_FILE
    echo "# It is generated for compatibility and smooth upgrades."                                                 >> $SEAFILE_ENV_FILE
    echo "# Remove it if you wan't to set the environment variables directly from docker (e.g. in a compose file)." >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_USER=${MYSQL_USER}"                                                                      >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_PASSWORD=${MYSQL_USER_PASSWD}"                                                           >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_CCNET_DB_NAME=${ccnet_db}"                                                               >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=${SEAFILE_DB}"                                                           >> $SEAFILE_ENV_FILE
    echo "SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=${SEAHUB_DB}"                                                             >> $SEAFILE_ENV_FILE
    echo "JWT_PRIVATE_KEY=$(pwgen -s 40 1)"                                                                         >> $SEAFILE_ENV_FILE
    echo "SEAFILE_SERVER_HOSTNAME=${SERVER_IP}"                                                                     >> $SEAFILE_ENV_FILE
    echo "SEAFILE_SERVER_PROTOCOL=${HTTP_PROTO}"                                                                    >> $SEAFILE_ENV_FILE
    echo "TIME_ZONE=${TZ:-UTC}"                                                                                     >> $SEAFILE_ENV_FILE

    print "Update database to Seafile 12 scheme"
    update_db 12.0.0
fi


echo "$REVISION" > "/shared/conf/revision"
print "Done!"
