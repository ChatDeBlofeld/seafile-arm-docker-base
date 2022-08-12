#!/bin/bash

set -Eeo pipefail

function sdbms() {
    if [ $dbms -eq 0 ]; then
        sdbms="SQLite"
    elif [ $dbms -eq 1 ]; then
        sdbms="MariaDB"
    else
        sdbms="MySQL"
    fi
}

function stest_case() {
    if [ $test_case -eq 0 ]; then
        stest_case="new instance"
    elif [ $test_case -eq 1 ]; then
        stest_case="go fileserver"
    else
        stest_case="update"
    fi
}

function print() {
    echo "[$platform|$sdbms|$stest_case] $@"
}

function exec() {
    docker exec $CONTAINER_NAME $@
}

function init_go_fileserver() {
    print "Prepare go fileserver tests"

}

function clean_go_fileserver() {
    print "Clean go fileserver tests"
}

function init_update() {
    print "Prepare update tests"
    sed -i "s/SEAFILE_IMAGE=.*/SEAFILE_IMAGE=${IMAGE_FQN}:${OLD_VERSION}/" $config
}

function clean_update() {
    print "Clean update tests"
}

function init_new_instance(){
    print "Prepare new instance tests"
}

function clean_new_instance(){
    print "Clean new instance tests"
}

function do_tests() {
    init_funcs=( init_new_instance init_go_fileserver init_update )
    clean_funcs=( clean_new_instance clean_go_fileserver clean_update )

    for dbms in 0 1 2
    do 
        write_env
        sdbms

        for test_case in "${!init_funcs[@]}"
        do
            stest_case
            ${init_funcs[$test_case]}

            print "Launch Seafile"
            $TOPOLOGY_DIR/compose.sh up -d &> /dev/null
            TIMEOUT=${TIMEOUT:=120}
            c=1
            while [[ "$(docker logs $CONTAINER_NAME |& grep -Pc '^Done\.$')" != "2" && $c -lt $TIMEOUT ]]
            do
                sleep 1
                let c++
            done
            docker network connect --alias "$WEB_HOSTNAME" "$FAKE_NETWORK" "$TOPOLOGY-reverse-proxy-1"

            if [ $c -eq $TIMEOUT ]; then 
                print "Launch reached timeout, pass"
                # TODO: write log to file
            else
                print "Launch tests"
                # TODO: e2e with codecept.js
                docker run --rm --net=seafile-ci --user pwuser -v $ROOT_DIR/tests:/tests \
                    -e SEAFILE_SERVER_VERSION=$SEAFILE_SERVER_VERSION \
                    -e URL=$URL \
                    -e PORT=$PORT \
                    -e SEAFILE_ADMIN_EMAIL=$SEAFILE_ADMIN_EMAIL \
                    -e SEAFILE_ADMIN_PASSWORD=$SEAFILE_ADMIN_PASSWORD \
                    codeceptjs/codeceptjs &> $ROOT_DIR/tests/logs/.log

                if [ $? -ne 0 ]; then
                    print "FAILED"
                fi
                # docker run --rm  -it --net=seafile-ci --user pwuser -v $PWD/tests:/tests codeceptjs/codeceptjs /bin/bash
                # docker run --rm  -it --net=seafile-ci -v $PWD/tests:/tests codeceptjs/codeceptjs /bin/bash
                # docker run --rm --net=seafile-ci --user pwuser -v $PWD/tests:/tests codeceptjs/codeceptjs
            fi

            # Cleaning
            ${clean_funcs[$test_case]}
            ./compose.sh down -v

            # TODO: remove
            exit
        done
    done
}

function write_env() {
    print "Write .env"

    echo "DBMS=$dbms
    NOSWAG=1
    NOSWAG_PORT=44444
    SEAFILE_IMAGE=$IMAGE_FQN:$platform
    URL=$URL
    PORT=$PORT
    SEAFILE_ADMIN_EMAIL=$SEAFILE_ADMIN_EMAIL
    SEAFILE_ADMIN_PASSWORD=$SEAFILE_ADMIN_PASSWORD
    USE_HTTPS=0
    MYSQL_HOST=db
    MYSQL_USER_PASSWD=secret
    MYSQL_ROOT_PASSWD=secret" > .env
}

echo "Loading environment..."
set -o allexport
[ -f .env ] && . .env
set +o allexport

while getopts R:D:r:u:i:v:h:d:l:P:o: flag
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
        o) export OLD_VERSION=$OPTARG;;
        :) exit;;
        \?) exit;; 
    esac
done

if [ ! "$OLD_VERSION" ]; then 
    echo "Missing OLD_VERSION"
    exit
fi
if [ "$REGISTRY" != "" ]; then REGISTRY="$REGISTRY/"; fi
IMAGE_FQN=$REGISTRY$REPOSITORY/$IMAGE

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

echo "Build images"
export NO_ENV=1
# ./build_image.sh

echo "Set up test topology"
# git clone https://github.com/ChatDeBlofeld/seafile-arm-docker
TOPOLOGY=seafile-test
TOPOLOGY_DIR=$ROOT_DIR/$TOPOLOGY
CONTAINER_NAME=$TOPOLOGY-seafile-1
FAKE_NETWORK=seafile-ci

# Runtime variables
URL=seafile.local
PORT=80
SEAFILE_ADMIN_EMAIL=you@your.email
SEAFILE_ADMIN_PASSWORD=secret

cp -r $ROOT_DIR/seafile-arm-docker $TOPOLOGY_DIR
cd $TOPOLOGY_DIR
sed -i 's/#~//g' compose.seafile.common.yml
if [ ! "$(docker network ls | grep ${FAKE_NETWORK})" ]; then
     docker network create "$FAKE_NETWORK"
fi

echo "Write nginx config"
config=$TOPOLOGY_DIR/nginx/seafile.noswag.conf
sed -i "s/your\.domain/${URL}/" $config
# TODO: modify file upstream
sed -i 's/#~//g' $config

IFS=',' read -r -a PLATFORMS <<< "$MULTIARCH_PLATFORMS"

for platform in "${PLATFORMS[@]}"
do
    platform=$(sed 's#linux/\(.*\)#\1#' <<< $platform)

    echo "Export $platform image to local images"
    # $ROOT_DIR/build_image.sh -t "$platform" -l "$platform"

    do_tests "$platform"
    
    echo "Cleaning image..."
    # todo : compose down ?
    # ./compose.sh down -v
    # docker rmi "$IMAGE_FQN":"$platform"
done

echo "Clean topology"
docker network rm "$FAKE_NETWORK"
# rm -rf $TOPOLOGY_DIR