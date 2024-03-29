#!/bin/bash

set -Eeo pipefail

if [ -z "$NO_ENV" ]
then
    echo "Loading environment..."
    set -a
    [ -f .env ] && . .env
    set +a
fi

while getopts R:D:r:u:i:t:v:l:P:f:pq flag
do
    case "${flag}" in
        R) REVISION=$OPTARG;;
        D) DOCKERFILE_DIR=$OPTARG;;
        f) DOCKERFILE="$OPTARG";;
        r) REGISTRY="$OPTARG/";;
        u) REPOSITORY=$OPTARG;;
        i) IMAGE=$OPTARG;;
        t) TAGS="$TAGS -t $REGISTRY$REPOSITORY/$IMAGE:$OPTARG";;
        p) OUTPUT="--push";;
        P) MULTIARCH_PLATFORMS=$OPTARG;;
        l) OUTPUT="--load"; MULTIARCH_PLATFORMS="linux/$OPTARG";;
        v) SEAFILE_SERVER_VERSION=$OPTARG;;
        q) QUIET="-q";;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$DOCKERFILE_DIR" ]; then DOCKERFILE_DIR="."; fi
if [ ! "$DOCKERFILE" ]; then DOCKERFILE="Dockerfile"; fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

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

# Download build script
if [ ! -f "$ROOT_DIR/build.sh" ]
then
    wget https://raw.githubusercontent.com/haiwen/seafile-rpi/master/build.sh -O "$ROOT_DIR/build.sh"
    chmod u+x "$ROOT_DIR/build.sh"
fi

set -x
# Build image
docker buildx build \
    $QUIET \
    -f "$DOCKERFILE" \
    --build-arg REVISION="$REVISION" \
    --build-arg SEAFILE_SERVER_VERSION="$SEAFILE_SERVER_VERSION" \
    $OUTPUT --platform "$MULTIARCH_PLATFORMS" $TAGS "$DOCKERFILE_DIR"
