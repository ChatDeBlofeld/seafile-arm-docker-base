#!/bin/bash

set -Eeuo pipefail

echo "Loading environment..."
set -a
[ -f .env ] && . .env
set +a

while getopts R:D:r:u:i:t:v:h:d:l:P:p flag
do
    case "${flag}" in
        R) REVISION=$OPTARG;;
        D) DOCKERFILE_DIR=$OPTARG;;
        r) REGISTRY="$OPTARG/";;
        u) REPOSITORY=$OPTARG;;
        i) IMAGE=$OPTARG;;
        t) TAGS="$TAGS -t $REGISTRY$REPOSITORY/$IMAGE:$OPTARG";;
        p) OUTPUT="--push";;
        P) MULTIARCH_PLATFORMS=$OPTARG;;
        l) OUTPUT="--load"; MULTIARCH_PLATFORMS="linux/$OPTARG";;
        v) SEAFILE_SERVER_VERSION=$OPTARG
           PYTHON_REQUIREMENTS_URL_SEAHUB="https://raw.githubusercontent.com/haiwen/seahub/v${SEAFILE_SERVER_VERSION}-server/requirements.txt"
           PYTHON_REQUIREMENTS_URL_SEAFDAV="https://raw.githubusercontent.com/haiwen/seafdav/v${SEAFILE_SERVER_VERSION}-server/requirements.txt"
           ;;
        h) PYTHON_REQUIREMENTS_URL_SEAHUB=$OPTARG;;
        d) PYTHON_REQUIREMENTS_URL_SEAFDAV=$OPTARG;;
        :) exit;;
        \?) exit;; 
    esac
done

if DOCKERFILE_DIR=""; then DOCKERFILE_DIR="."; fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

# Register/update emulators
docker run --rm --privileged tonistiigi/binfmt --install all >/dev/null

# create multiarch builder if needed
BUILDER=multiarch_builder
if [ "$(docker buildx ls | grep $BUILDER)" == "" ]
then
    docker buildx create --name $BUILDER
fi

# Use the builder
docker buildx use $BUILDER

# Fix docker multiarch building when host local IP changes
# FIXME: restarting causes "error: dial unix /run/buildkit/buildkitd.sock: connect: no such file or directory"
# BUILDER_CONTAINER="$(docker ps -qf name=$BUILDER)"
# if [ ! -z "${BUILDER_CONTAINER}" ]; then
#   echo 'Restarting builder container..'
#   docker restart $(docker ps -qf name=$BUILDER)
#   sleep 2
# fi

# Build image
docker buildx build \
    --build-arg REVISION=$REVISION \
    --build-arg SEAFILE_SERVER_VERSION=$SEAFILE_SERVER_VERSION \
    --build-arg PYTHON_REQUIREMENTS_URL_SEAHUB=$PYTHON_REQUIREMENTS_URL_SEAHUB \
    --build-arg PYTHON_REQUIREMENTS_URL_SEAFDAV=$PYTHON_REQUIREMENTS_URL_SEAFDAV \
    $OUTPUT --platform "$MULTIARCH_PLATFORMS" $TAGS "$DOCKERFILE_DIR"
