#!/bin/bash

set -Eeo pipefail

while getopts l:pn flag
do
    case "${flag}" in
        p) PIP=true;;
        n) NATIVE=true;;
        l) platform="$(sed 's#linux/##' <<< $OPTARG)";
           TAG="$(sed 's#/##' <<< $platform)";;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

REQUIREMENTS_DIR="/requirements"

if [[ -f "$REQUIREMENTS_DIR/native/$TAG.txt" && $NATIVE ]]; then
    grep -vE '^#' "$REQUIREMENTS_DIR/native/$TAG.txt" | xargs apt-get install -y
fi

if [ $PIP ]; then
    mkdir -p /haiwen-build/seahub_thirdparty
    if [ -f "$REQUIREMENTS_DIR/thirdpart/$TAG.txt" ]; then 
        python3 -m pip install -r "$REQUIREMENTS_DIR/thirdpart/$TAG.txt" --target /haiwen-build/seahub_thirdparty --no-cache --upgrade
    fi

    if [ -f "$REQUIREMENTS_DIR/thirdpart_no_deps/$TAG.txt" ]; then 
        python3 -m pip install -r "$REQUIREMENTS_DIR/thirdpart_no_deps/$TAG.txt" --target /haiwen-build/seahub_thirdparty --no-cache --upgrade --no-deps
    fi

    # rm -rf $(find /haiwen-build/seahub_thirdparty -name "__pycache__")
fi
