#!/bin/bash

set -Eeo pipefail

print_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  -B            Prepare build (run prepare_build.sh)
  -R <rev>      Revision (required)                       [REVISION]
  -D <dir>      Dockerfile directory (default: .)         [DOCKERFILE_DIR]
  -f <file>     Dockerfile path (default: Dockerfile)     [DOCKERFILE]
  -r <registry> Registry (optional)                       [REGISTRY]
  -u <repo>     Repository (required)                     [REPOSITORY]
  -i <image>    Image name (required)                     [IMAGE]
  -t <tag>      Tag (required, can be used multiple times)
  -p            Push multi-platform image to registry
  -P <plats>    Platforms (comma-separated, required)     [MULTIARCH_PLATFORMS]
  -l <arch>     Load single architecture locally
  -v <version>  Seafile server version (required)         [SEAFILE_SERVER_VERSION]
  -q            Quiet mode
  -h            Show this help and exit

You can also set any of the bracketed environment variables above in a .env file
in the script directory, instead of passing them as command line arguments.
Command line arguments take precedence over settings defined in the .env file.

EOF
}

if [ -z "$NO_ENV" ]
then
    echo "Loading environment..."
    set -a
    [ -f .env ] && . .env
    set +a
fi

while getopts BR:D:f:r:u:i:t:pP:l:v:qh flag
do
    case "${flag}" in
        B) PREPARE=true;;
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
        h) print_help; exit 0;;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$DOCKERFILE_DIR" ]; then DOCKERFILE_DIR="."; fi
if [ ! "$DOCKERFILE" ]; then DOCKERFILE="Dockerfile"; fi

# Check required variables
if [ -z "$REVISION" ]; then
    echo "Error: REVISION is required"
    exit 1
fi

if [ -z "$REPOSITORY" ]; then
    echo "Error: REPOSITORY is required"
    exit 1
fi

if [ -z "$IMAGE" ]; then
    echo "Error: IMAGE is required"
    exit 1
fi

if [ -z "$MULTIARCH_PLATFORMS" ]; then
    echo "Error: MULTIARCH_PLATFORMS is required"
    exit 1
fi

if [ -z "$SEAFILE_SERVER_VERSION" ]; then
    echo "Error: SEAFILE_SERVER_VERSION is required"
    exit 1
fi

if [ -z "$TAGS" ]; then
    echo "Error: At least one tag (-t) is required"
    exit 1
fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

# Register/update emulators
docker pull tonistiigi/binfmt:latest >/dev/null
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

if [ $PREPARE ]; then
    "$ROOT_DIR/prepare_build.sh"
fi

set -x
# Build image
docker buildx build \
    $QUIET \
    -f "$DOCKERFILE" \
    --build-arg REVISION="$REVISION" \
    --build-arg SEAFILE_SERVER_VERSION="$SEAFILE_SERVER_VERSION" \
    $OUTPUT --platform "$MULTIARCH_PLATFORMS" $TAGS "$DOCKERFILE_DIR"
