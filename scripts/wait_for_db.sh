#!/bin/bash

set -Eeo pipefail

EXPECTED_ERROR_CODE=1045

export PYTHONPATH=${PYTHONPATH}:/opt/seafile/seafile-server-${SEAFILE_SERVER_VERSION}/seahub/thirdpart

# Wait until the connection is refused for no password
python3 - <<PYTHON_SCRIPT
import MySQLdb
from time import sleep

c = 1
while True:
    try:
        db=MySQLdb.connect(host="${MYSQL_HOST}", port=${MYSQL_PORT})
    except MySQLdb.OperationalError as err:
        if err.args[0] == ${EXPECTED_ERROR_CODE}:
            break
        elif not c % 10:
            print("Still waiting... Is [${MYSQL_HOST}:${MYSQL_PORT}] reachable from within the container?")
    c+= 1
    sleep(1)
PYTHON_SCRIPT
