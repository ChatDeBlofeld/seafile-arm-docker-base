#!/bin/bash

# Install thirdpart dependencies that are not pure python dependencies
# Adapted from dependencies of the manual https://manual.seafile.com/deploy/using_mysql/
# Dependencies can be installed with pip or as system package, depending
# on what's the more convenient (i.e system packages for arch with no wheels support
# and with pip for the others),

set -Eeo pipefail

while getopts l:pn flag
do
    case "${flag}" in
        p) PYTHON=true;;
        n) NATIVE=true;;
        l) arch="$(sed 's#linux/##' <<< $OPTARG)";
           TAG="$(sed 's#/##' <<< $arch)";;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

REQUIREMENTS_DIR="/requirements"

if [[ -f "$REQUIREMENTS_DIR/native/$TAG.txt" && $NATIVE ]]; then
    grep -vE '^#' "$REQUIREMENTS_DIR/native/$TAG.txt" | xargs apt-get install -y
fi

if [ $PYTHON ]; then
    mkdir -p /haiwen-build/seahub_thirdparty
    if [ -f "$REQUIREMENTS_DIR/python/$TAG.txt" ]; then 
        python3 -m pip install -r "$REQUIREMENTS_DIR/python/$TAG.txt" --target /seafile/seahub/thirdpart --no-cache --upgrade
    fi

    if [ -f "$REQUIREMENTS_DIR/python_no_deps/$TAG.txt" ]; then 
        python3 -m pip install -r "$REQUIREMENTS_DIR/python_no_deps/$TAG.txt" --target /seafile/seahub/thirdpart --no-cache --upgrade --no-deps
    fi

    # rm -rf $(find /haiwen-build/seahub_thirdparty -name "__pycache__")
fi
