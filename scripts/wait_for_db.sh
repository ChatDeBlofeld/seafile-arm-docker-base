#!/bin/bash

ALLOWED_ERROR_CODE=1045

export PYTHONPATH=${PYTHONPATH}:/opt/seafile/seafile-server-${VERSION}/seahub/thirdpart

python3 - <<PYTHON_SCRIPT
import MySQLdb

while True:
    try:
        db=MySQLdb.connect(host="${MYSQL_HOST}")
    except MySQLdb.OperationalError as err:
        if err.args[0] == ${ALLOWED_ERROR_CODE}:
            break
PYTHON_SCRIPT
