#!/bin/bash

set -Eeo pipefail

print_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  -B <image>    Builder image (required)                  [BUILDER_IMAGE]
  -o <dir>      Output directory (default: ./seafile)     [OUTPUT_DIR]
  -p <dir>      Packages directory (default: ./packages)  [PACKAGES_DIR]
  -P <plats>    Platforms (comma-separated, required)     [MULTIARCH_PLATFORMS]
  -v <version>  Seafile server version (required)         [SEAFILE_SERVER_VERSION]
  -h            Show this help and exit

Builder image will be automatically suffixed with the platform architecture, like '$BUILDER_IMAGE-arm64'.

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

while getopts B:o:p:P:v:h flag
do
    case "${flag}" in
        B) BUILDER_IMAGE=$OPTARG;;
        o) OUTPUT_DIR=$OPTARG;;
        p) PACKAGES_DIR=$OPTARG;;
        P) MULTIARCH_PLATFORMS=$OPTARG;;
        v) SEAFILE_SERVER_VERSION=$OPTARG;;
        h) print_help; exit 0;;
        :) exit 1;;
        \?) exit 1;; 
    esac
done

if [ ! "$PACKAGES_DIR" ]; then PACKAGES_DIR="./packages"; fi
if [ ! "$OUTPUT_DIR" ]; then OUTPUT_DIR="./seafile"; fi

# Check required variables
if [ -z "$BUILDER_IMAGE" ]; then
    echo "Error: BUILDER_IMAGE is required"
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

if [ ! -d "$PACKAGES_DIR" ]; then
    echo "Packages directory does not exist"
    exit 1
fi

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$ROOT_DIR"

# Register/update emulators
docker pull tonistiigi/binfmt:latest >/dev/null
docker run --rm --privileged tonistiigi/binfmt --install all >/dev/null

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
    # Use the latest (most recently modified) package if multiple exist for the same version
    archive=$(ls -t $PACKAGES_DIR/$tag/seafile-server-$SEAFILE_SERVER_VERSION-*.tar.gz 2>/dev/null | head -n 1)
    if [ -z "$archive" ]; then
        echo "No archive found for $tag"
        exit 1
    fi
    tar -xzf "$archive" -C "$OUTPUT_DIR/$platform"
    mv "$base_dir/seahub/media" "$OUTPUT_DIR/$platform/"

    # Install needed dependencies
    cmd="/requirements/install.sh -pl $platform && chown -R $(id -u):$(id -g) /seafile/seahub/thirdpart"
    set -x
    id=($(docker run -d --rm \
        -v "$ROOT_DIR/requirements":/requirements \
        -v "$base_dir":/seafile \
        "$BUILDER_IMAGE-$tag" /bin/bash -c "$cmd"))
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
