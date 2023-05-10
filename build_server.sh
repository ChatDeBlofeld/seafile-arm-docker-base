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
        c) CACHE_DIR=$OPTARG;;
        # t) TAGS="$TAGS -t $REGISTRY$REPOSITORY/$IMAGE:$OPTARG";;
        # p) OUTPUT="--push";;
        P) MULTIARCH_PLATFORMS=$OPTARG;;
        e) EXPORT=1;;
        # l) OUTPUT="--load"; MULTIARCH_PLATFORMS="linux/$OPTARG";;
        v) SEAFILE_SERVER_VERSION=$OPTARG;;
        # q) QUIET="-q";;
        1) ARGS=$ARGS" -1";;
        2) ARGS=$ARGS" -2";;
        3) ARGS=$ARGS" -3";;
        4) ARGS=$ARGS" -4";;
        5) ARGS=$ARGS" -5";;
        6) ARGS=$ARGS" -6";;
        7) ARGS=$ARGS" -7";;
        8) ARGS=$ARGS" -8";;
        9) ARGS=$ARGS" -9";;
        A) ARGS=$ARGS" -A";;
        T) THIRDPART=1;;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$CACHE_DIR" ]; then CACHE_DIR="./cache"; fi
if [ ! "$OUTPUT_DIR" ]; then OUTPUT_DIR="./seafile"; fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

CACHE_DIR="$ROOT_DIR/$CACHE_DIR"
OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"

# Currently sequential cause of deadlocks, need to dig
IFS=',' read -r -a PLATFORMS <<< "$MULTIARCH_PLATFORMS"
for platform in "${PLATFORMS[@]}"
do
    distro="$(sed 's#linux/##' <<< $platform)"
    tag="$(sed 's#/##' <<< $distro)"

    if [ ! -d "$CACHE_DIR/$tag" ]; then
        mkdir -p "$CACHE_DIR/$tag"
    fi

    if [ $THIRDPART ]; then
        cmd="/requirements/install.sh -pl $platform && "
    fi

    cmd=$cmd"/build.sh $ARGS -v $SEAFILE_SERVER_VERSION"
    cmd=$cmd" && chown -R $(id -u):$(id -g) /built-seafile-server-pkgs"

    # docker pull --platform $platform $BUILDER_IMAGE

    docker rm --force "seafile_builder_$tag"

    (set -x;
    docker run -it --rm \
        --name "seafile_builder_$tag" \
        --platform $platform \
        --pull always \
        -v "$ROOT_DIR/build.sh":/build.sh \
        -v "$ROOT_DIR/requirements":/requirements \
        -v "$CACHE_DIR/$tag/haiwen-build":/haiwen-build \
        -v "$CACHE_DIR/$tag/built-seafile-sources":/built-seafile-sources \
        -v "$CACHE_DIR/$tag/root/opt/local":/root/opt/local \
        -v "$CACHE_DIR/$tag/built-seafile-server-pkgs":/built-seafile-server-pkgs \
        $BUILDER_IMAGE /bin/bash -c "$cmd")

    if [ $EXPORT ]; then
        distro="$(sed 's#linux/##' <<< $platform)"
        tag="$(sed 's#/##' <<< $distro)"

        if [ ! -d "$OUTPUT_DIR/$platform" ]; then
            mkdir -p "$OUTPUT_DIR/$platform"
        fi

        # Terribly slow in the Dockerfile but very quick here, then done here
        rm -rf "$OUTPUT_DIR/$platform"
        mkdir -p "$OUTPUT_DIR/$platform"

        tar -xzf $CACHE_DIR/$tag/built-seafile-server-pkgs/*.tar.gz -C "$OUTPUT_DIR/$platform"
        mv "$OUTPUT_DIR/$platform/seafile-server-$SEAFILE_SERVER_VERSION/seahub/media" "$OUTPUT_DIR/$platform/"

        rm -f "$OUTPUT_DIR/$platform/seafile-server-$SEAFILE_SERVER_VERSION/setup-seafile-mysql.py"
        rm -f "$OUTPUT_DIR/$platform/seafile-server-$SEAFILE_SERVER_VERSION/upgrade/db_update_helper.py"
        cp "$ROOT_DIR/custom/setup-seafile-mysql.py" "$OUTPUT_DIR/$platform/seafile-server-$SEAFILE_SERVER_VERSION/setup-seafile-mysql.py"
        cp "$ROOT_DIR/custom/db_update_helper.py" "$OUTPUT_DIR/$platform/seafile-server-$SEAFILE_SERVER_VERSION/upgrade/db_update_helper.py"
        chmod -R g+w "$OUTPUT_DIR/$platform"
    fi
done
