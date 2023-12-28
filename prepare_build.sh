#!/bin/bash

set -Eeo pipefail

if [ -z "$NO_ENV" ]
then
    echo "Loading environment..."
    set -a
    [ -f .env ] && . .env
    set +a
fi

while getopts B:o:c:P:e123456789ATv: flag
do
    case "${flag}" in
        # R) REVISION=$OPTARG;;
        # D) DOCKERFILE_DIR=$OPTARG;;
        # f) DOCKERFILE="$OPTARG";;
        # r) REGISTRY="$OPTARG/";;
        # u) REPOSITORY=$OPTARG;;
        # i) IMAGE=$OPTARG;;
        B) BUILDER_IMAGE=$OPTARG;;
        o) OUTPUT_DIR=$OPTARG;;
        p) PACKAGES_DIR=$OPTARG;;
        P) MULTIARCH_PLATFORMS=$OPTARG;;
        e) EXPORT=1;;
        # l) OUTPUT="--load"; MULTIARCH_PLATFORMS="linux/$OPTARG";;
        v) SEAFILE_SERVER_VERSION=$OPTARG;;
        # q) QUIET="-q";;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$PACKAGES_DIR" ]; then PACKAGES_DIR="./packages"; fi
if [ ! "$OUTPUT_DIR" ]; then OUTPUT_DIR="./seafile"; fi

if [ ! -d "$PACKAGES_DIR" ]; then
    echo "Packages directory does not exist"
    exit 1
fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

CACHE_DIR="$ROOT_DIR/$CACHE_DIR"
OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
LOGS_DIR="$ROOT_DIR/logs/deps"

if [ ! -d "$LOGS_DIR" ]; then
    mkdir -p "$LOGS_DIR"
fi

# Currently sequential cause of deadlocks, need to dig
# (not anymore but not tested)
IFS=',' read -r -a PLATFORMS <<< "$MULTIARCH_PLATFORMS"
ids=()

for platform in "${PLATFORMS[@]}"
do
    arch="$(sed 's#linux/##' <<< $platform)"
    tag="$(sed 's#/##' <<< $arch)"

    # Remove old files
    rm -rf "$OUTPUT_DIR/$platform"
    mkdir -p "$OUTPUT_DIR/$platform"
    base_dir="$OUTPUT_DIR/$platform/seafile-server-$SEAFILE_SERVER_VERSION"

    # Prepare files from archive
    tar -xzf $PACKAGES_DIR/$tag/seafile-server-$SEAFILE_SERVER_VERSION-*.tar.gz -C "$OUTPUT_DIR/$platform"
    mv "$base_dir/seahub/media" "$OUTPUT_DIR/$platform/"

    # Install needed dependencies
    cmd="/requirements/install.sh -pl $platform && chown -R $(id -u):$(id -g) /seafile/seahub/thirdpart"
    set -x
    id=($(docker run -d --rm \
        --platform $platform \
        --pull always \
        -v "$ROOT_DIR/requirements":/requirements \
        -v "$base_dir":/seafile \
        $BUILDER_IMAGE /bin/bash -c "$cmd"))
    set +x

    ids+=($id)
    docker logs -f $id &> "$LOGS_DIR/$tag.log" &
done

function quit() {
    for id in "${ids[@]}"
    do
        docker stop $id
    done
    exit
}

trap quit SIGTERM
trap quit SIGINT

wait

chmod -R g+w "$OUTPUT_DIR"
