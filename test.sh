#!/bin/bash

set -Eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function print() {
    echo -e "[$platform|$sdbms|$stest_case] $@"
}

function init_update() {
    print "Prepare update tests"
    MIN_VERSION=$OLD_VERSION
    sed -i "s#SEAFILE_IMAGE=.*#SEAFILE_IMAGE=${IMAGE_FQN}:${OLD_VERSION}#" $TOPOLOGY_DIR/.env
    launch

    if [ $? -ne 0 ]; then 
        print "Launching previous version failed"
        return 1
    fi

    sed -i "s#SEAFILE_IMAGE=.*#SEAFILE_IMAGE=${IMAGE_FQN}:${1}#" $TOPOLOGY_DIR/.env
}

function init_new_instance(){
    print "Prepare new instance tests"
    MIN_VERSION=$MAJOR_VERSION
}

function launch() {
    $TOPOLOGY_DIR/compose.sh up -d &> /dev/null
    if [ $? -ne 0 ]; then
        $TOPOLOGY_DIR/compose.sh up -d &> $LOGS_FOLDER/launch-$(date +"%s")
        return 1
    fi

    timeout=${timeout:=300}
    c=1
    while [[ "$(docker logs $CONTAINER_NAME |& grep -Pc '^Done\.$')" != "2" && $c -lt $timeout ]]
    do
        sleep 1
        let c++
    done

    if [ $c -eq $timeout ]; then 
        docker logs $CONTAINER_NAME &> $LOGS_FOLDER/$(date +"%s")-launch.log
        return 1
    fi
}

function check_gc() {
    # Depends only on current image
    if [[ $failed -ne 0 || $GC_MIN_VERSION -gt $MAJOR_VERSION ]]; then
        return 0
    fi

    echo "----------- GC TEST ----------"
    echo "Check if garbage collection works"
    $TOPOLOGY_DIR/compose.sh stop seafile &> /dev/null
    log=$($TOPOLOGY_DIR/compose.sh run --rm seafile gc 2>&1 || echo failed_flag)

    if [ "$(echo -e $log | grep 'failed_flag')" != "" ]; then
        echo "Garbage collection failed"
        echo $log > $LOGS_FOLDER/$(date +"%s")-gc.log
        return 1
    fi
}

function check_memcached() {
    if [[ $failed -ne 0 || $MEMCACHED_MIN_VERSION -gt $MIN_VERSION ]]; then
        return 0
    fi

    echo "------- MEMCACHED TEST -------"
    echo "Check if memcached is configured correctly"
    memcached_logs=$($TOPOLOGY_DIR/compose.sh logs memcached)

    if [ ! "$(echo $memcached_logs | grep 'STORED')" ]
    then
        echo "Memcached is not set correctly"
        echo $memcached_logs > $LOGS_FOLDER/$(date +"%s")-memcached.log
        return 1
    fi
}

function check_notification_server() {
    if [[ $dbms -eq 0 || $failed -ne 0 || $NOTIFICATION_SERVER_MIN_VERSION -gt $MIN_VERSION ]]; then
        return 0
    fi

    echo "-- NOTIFICATION SERVER TEST --"
    echo "Check if notification server is configured correctly"
    log=$(curl --no-progress-meter http://$HOST:$PORT/notification/ping/ 2>&1)
    pong=$(echo "$log" | jq -r '.ret' 2> /dev/null)

    if [[ "$pong" != "pong" ]]
    then
        echo "Failed to ping notification server"
        echo $log > $LOGS_FOLDER/$(date +"%s")-notification_server.log
        return 1
    fi
}

function check_webdav() {
    if [[ $failed -ne 0 || $WEBDAV_MIN_VERSION -gt $MIN_VERSION ]]; then
        return 0
    fi

    echo "-------- WEBDAV TESTS --------"
    flag=0
    $ROOT_DIR/tests/webdav_tests.sh || flag=1
    return $flag
}

function clean() {
    print "Cleaning..."
    $TOPOLOGY_DIR/compose.sh down -v &> /dev/null
}

function do_tests() {
    lsdbms=( "MariaDB" "MySQL" )
    stest_cases=( "New instance" "Major update" )
    init_funcs=( init_new_instance init_update )

    for dbms in "${!lsdbms[@]}"
    do 
        sdbms=${lsdbms[$dbms]}

        for test_case in "${!init_funcs[@]}"
        do
            stest_case=${stest_cases[$test_case]}
            write_env "$1" "$dbms"
            ${init_funcs[$test_case]} "$1"

            if [ $? -ne 0 ]; then 
                print "${RED}Initialization failed, pass${NC}"
                FAILED=1
                clean
                continue
            fi

            print "Launch Seafile"
            launch

            if [ $? -ne 0 ]; then 
                print "${RED}Launch failed, pass${NC}"
                FAILED=1
                clean
                continue
            fi

            print "Launch tests"
            failed=0
            $ROOT_DIR/tests/seahub_tests.sh || failed=1
            check_webdav || failed=1
            check_memcached || failed=1
            check_notification_server || failed=1
            # Has to be the last check since it stops the server
            check_gc || failed=1

            if [ $failed -ne 0 ]; then
                FAILED=1
                docker logs $CONTAINER_NAME &> $LOGS_FOLDER/$(date +"%s")-launch.log
                print "${RED}Failed${NC}"
            fi

            clean
        done
    done
}

function write_env() {
    print "Write .env"

    echo "DBMS=$2
    NOSWAG=1
    NOSWAG_PORT=$PORT
    SEAFILE_IMAGE=$IMAGE_FQN:$1
    PUID=$(id -u)
    PGID=$(id -g)
    HOST=$HOST
    PORT=$PORT
    SEAFILE_ADMIN_EMAIL=$SEAFILE_ADMIN_EMAIL
    SEAFILE_ADMIN_PASSWORD=$SEAFILE_ADMIN_PASSWORD
    USE_HTTPS=0
    MYSQL_HOST=db
    MYSQL_USER_PASSWD=secret
    MYSQL_ROOT_PASSWD=secret
    SEAFILE_CONF_DIR=conf
    SEAFILE_LOGS_DIR="$LOGS_FOLDER/$(date +"%s")"
    SEAFILE_DATA_DIR=data
    SEAFILE_SEAHUB_DIR=seahub
    DATABASE_DIR=db
    WEBDAV=1
    NOTIFICATION_SERVER=1
    MEMCACHED_HOST=memcached:11211" > $TOPOLOGY_DIR/.env
}

echo "Loading environment..."
set -o allexport
[ -f .env ] && . .env
set +o allexport
[ -f ./tests/feature_table.env ] && . ./tests/feature_table.env

while getopts R:D:r:u:i:v:h:d:l:P:o:b:B flag
do
    case "${flag}" in
        R) export REVISION=$OPTARG;;
        D) export DOCKERFILE_DIR=$OPTARG;;
        r) export REGISTRY="$OPTARG/";;
        u) export REPOSITORY=$OPTARG;;
        i) export IMAGE=$OPTARG;;
        P) export MULTIARCH_PLATFORMS=$OPTARG;;
        l) export MULTIARCH_PLATFORMS="linux/$OPTARG";;
        v) export SEAFILE_SERVER_VERSION=$OPTARG
           export PYTHON_REQUIREMENTS_URL_SEAHUB="https://raw.githubusercontent.com/haiwen/seahub/v${SEAFILE_SERVER_VERSION}-server/requirements.txt"
           export PYTHON_REQUIREMENTS_URL_SEAFDAV="https://raw.githubusercontent.com/haiwen/seafdav/v${SEAFILE_SERVER_VERSION}-server/requirements.txt"
           ;;
        h) export PYTHON_REQUIREMENTS_URL_SEAHUB=$OPTARG;;
        d) export PYTHON_REQUIREMENTS_URL_SEAFDAV=$OPTARG;;
        o) OLD_VERSION=$OPTARG;;
        b) BRANCH=$OPTARG;;
        B) BUILD=1;;
        :) exit;;
        \?) exit;; 
    esac
done

if [ ! "$OLD_VERSION" ]; then 
    echo "Missing OLD_VERSION"
    exit
fi

if [ "$REGISTRY" != "" ]; then REGISTRY="$REGISTRY/"; fi
if [ "$BRANCH" == "" ]; then BRANCH="master"; fi
IMAGE_FQN=$REGISTRY$REPOSITORY/$IMAGE

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

if [ "$BUILD" = "1" ]
then
    echo "Build images"
    export NO_ENV=1
    ./build_image.sh
fi

echo "Set up test topology"
MAJOR_VERSION=${SEAFILE_SERVER_VERSION%%.*}
TOPOLOGY=test-topology
TOPOLOGY_DIR=$ROOT_DIR/$TOPOLOGY
cd $ROOT_DIR
rm -rf $TOPOLOGY_DIR
git clone https://github.com/ChatDeBlofeld/seafile-arm-docker $TOPOLOGY &> /dev/null
CONTAINER_NAME=$TOPOLOGY-seafile-1
rm -rf logs/test
mkdir -p logs/test
cd $TOPOLOGY_DIR
git checkout $BRANCH


# Runtime variables
export HOST=127.0.0.1
export PORT=44444
export SEAFILE_ADMIN_EMAIL=you@your.email
export SEAFILE_ADMIN_PASSWORD=secret
export LOGS_FOLDER=$ROOT_DIR/logs/test

sed -i 's/#~//g' compose.seafile.yml
write_env latest 1 &> /dev/null
$TOPOLOGY_DIR/compose.sh down -v &> /dev/null

echo "Write nginx config"
config=$TOPOLOGY_DIR/nginx/seafile.noswag.conf
sed -i "s/your\.domain/${HOST}/" $config
sed -i 's/#~//g' $config

IFS=',' read -r -a PLATFORMS <<< "$MULTIARCH_PLATFORMS"

for platform in "${PLATFORMS[@]}"
do
    platform="$(sed 's#linux/##' <<< $platform)"
    tag="$(sed 's#/##' <<< $platform)"

    if [ "$BUILD" = 1 ]
    then
        echo "Export $platform image to local images"
        $ROOT_DIR/build_image.sh -t "$tag" -l "$platform"
    fi
    
    if [ "$(docker images -qf reference="${IMAGE_FQN}:${tag}")" = "" ]
    then
        echo -e "${RED}Can't find image for ${platform}, pass${NC}"
        FAILED=1
    else
        do_tests "$tag"
    fi
done

echo "Clean topology"
rm -rf $TOPOLOGY_DIR

if [[ FAILED -ne 0 ]]; then
    echo -e "${RED}FAILED${NC}"
else
    echo -e "${GREEN}SUCCESS${NC}"
fi