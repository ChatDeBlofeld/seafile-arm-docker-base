#!/bin/bash

DOCKERFILE_DIR="."
MULTIARCH_PLATFORMS="linux/amd64,linux/arm/v7,linux/arm64"

VERSION="8.0.6"
PYTHON_REQUIREMENTS_URL_SEAHUB="https://raw.githubusercontent.com/haiwen/seahub/v${VERSION}-server/requirements.txt"
PYTHON_REQUIREMENTS_URL_SEAFDAV="https://raw.githubusercontent.com/haiwen/seafdav/v${VERSION}-server/requirements.txt"

REGISTRY=""
REPOSITORY="franchetti"
IMAGE="seafile-arm"
TAGS=""

OUTPUT=""
while getopts r:u:i:t:v:h:d:l:p flag
do
    case "${flag}" in
        r) REGISTRY="$OPTARG/";;
        u) REPOSITORY=$OPTARG;;
        i) IMAGE=$OPTARG;;
        t) TAGS="$TAGS -t $REGISTRY$REPOSITORY/$IMAGE:$OPTARG";;
        p) OUTPUT="--push";;
        P) MULTIARCH_PLATFORMS=$OPTARG;;
        l) OUTPUT="--load"; MULTIARCH_PLATFORMS="linux/$OPTARG";;
        v) VERSION=$OPTARG
           PYTHON_REQUIREMENTS_URL_SEAHUB="https://raw.githubusercontent.com/haiwen/seahub/v${VERSION}-server/requirements.txt"
           PYTHON_REQUIREMENTS_URL_SEAFDAV="https://raw.githubusercontent.com/haiwen/seafdav/v${VERSION}-server/requirements.txt"
           ;;
        h) PYTHON_REQUIREMENTS_URL_SEAHUB=$OPTARG;;
        d) PYTHON_REQUIREMENTS_URL_SEAFDAV=$OPTARG;;
        :) exit;;
        \?) exit;; 
    esac
done

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

# Register qemu handlers
docker run --rm --privileged docker/binfmt:a7996909642ee92942dcd6cff44b9b95f08dad64

# create multiarch builder if needed
BUILDER=multiarch_builder
if [ "$(docker buildx ls | grep $BUILDER)" == "" ]
then
    docker buildx create --name $BUILDER
fi

# Use the builder
docker buildx use $BUILDER

# Fix docker multiarch building when host local IP changes
BUILDER_CONTAINER="$(docker ps -qf name=$BUILDER)"
if [ ! -z "${BUILDER_CONTAINER}" ]; then
  echo 'Restarting builder container..'
  docker restart $(docker ps -qf name=$BUILDER)
  sleep 2
fi

# Build image
docker buildx build \
    --build-arg VERSION=$VERSION \
    --build-arg PYTHON_REQUIREMENTS_URL_SEAHUB=$PYTHON_REQUIREMENTS_URL_SEAHUB \
    --build-arg PYTHON_REQUIREMENTS_URL_SEAFDAV=$PYTHON_REQUIREMENTS_URL_SEAFDAV \
    $OUTPUT --platform "$MULTIARCH_PLATFORMS" $TAGS "$DOCKERFILE_DIR"
