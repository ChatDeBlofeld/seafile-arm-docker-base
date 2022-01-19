#!/bin/bash

export PYTHONPATH=${PYTHONPATH}:/opt/seafile/seafile-server-${SEAFILE_SERVER_VERSION}/seahub/thirdpart

CCNET_DB=${CCNET_DB:=ccnet_db}
SEAFILE_DB=${SEAFILE_DB:=seafile_db}
SEAHUB_DB=${SEAHUB_DB:=seahub_db}

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
