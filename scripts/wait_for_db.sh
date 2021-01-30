#!/bin/bash

EXPECTED_ERROR_CODE=1045

export PYTHONPATH=${PYTHONPATH}:/opt/seafile/seafile-server-${VERSION}/seahub/thirdpart

# Wait until the connection is refused for no password
python3 - <<PYTHON_SCRIPT
import MySQLdb

while True:
    try:
        db=MySQLdb.connect(host="${MYSQL_HOST}", port=${MYSQL_PORT})
    except MySQLdb.OperationalError as err:
        if err.args[0] == ${EXPECTED_ERROR_CODE}:
            break
PYTHON_SCRIPT
