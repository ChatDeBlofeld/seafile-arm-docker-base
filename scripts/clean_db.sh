#!/bin/bash

export PYTHONPATH=${PYTHONPATH}:/opt/seafile/seafile-server-${SEAFILE_SERVER_VERSION}/seahub/thirdpart

if [ ! "$CCNET_DB" ]; then CCNET_DB="ccnet_db"; fi
if [ ! "$SEAFILE_DB" ]; then SEAFILE_DB="seafile_db"; fi
if [ ! "$SEAHUB_DB" ]; then SEAHUB_DB="seahub_db"; fi

python3 - <<PYTHON_SCRIPT
import MySQLdb

try:
    db = MySQLdb.connect(host="${MYSQL_HOST}", port=${MYSQL_PORT}, user="root", password="${MYSQL_ROOT_PASSWD}")
    cursor = db.cursor()

    cursor.execute("DROP DATABASE ${CCNET_DB}")
    cursor.execute("DROP DATABASE ${SEAFILE_DB}")
    cursor.execute("DROP DATABASE ${SEAHUB_DB}")
except MySQLdb.OperationalError:
    pass

db.close()
PYTHON_SCRIPT
