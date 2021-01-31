# Seafile Docker image for ARM

## About

A [Docker image](https://hub.docker.com/r/franchetti/seafile-arm) of the [Seafile](https://www.seafile.com/en/home/)  data synchronization system targeting ARMv7 and ARM64 platforms, like Raspberry Pi or Pine 64 boards. 

This repository is part of [a bigger project](https://github.com/ChatDeBlofeld/seafile-arm-docker) intended for bringing a full working Seafile environment (Seafile server, database server, web server with TLS support) in no time.

The build step uses [a forked version]( https://github.com/ChatDeBlofeld/seafile-rpi ) of the [Seafile for Raspberry PI]( https://github.com/haiwen/seafile-rpi ) build script.

## Build

Update the `USER` variable in the `build-image.sh` script, then run it. Current version on master is Seafile v8.0.3, for older builds, checkout on the proper tag.

Script usage:

```
build-image.sh [OPTIONS]

Options:
    -t              Add a tag. Can be used several times.
    -l <platform>   Load to the local images. One <platform> at time only.
    -p              Push the image(s) to the remote registry. Incompatible with -l
```

Example:

```Bash
$ ./build-image.sh -t 8 -t latest -l amd64
```

##  Run

Currently MySQL only.

Example of run, see below for a more detailed description of the arguments:

```Bash
$ docker run --rm -v /path/to/seafile/data/:/shared \
                  -p 8000:8000 -p 8082:8082 \
                  -e PUID=1001 -e PGID=1001 \
                  -e SERVER_IP=cloud.my.domain \
                  -e ENABLE_TLS=true \
                  -e SEAFILE_ADMIN_EMAIL=me@my.domain \
                  -e SEAFILE_ADMIN_PASSWORD=secret \
                  -e MYSQL_HOST=db.hostname \
                  -e MYSQL_USER_PASSWD=secret \
                  -e MYSQL_ROOT_PASSWD=secret \
                  franchetti/seafile-arm
```

### Persistency

Expose the `/shared` folder within a volume:

```
-v /path/to/seafile/data/:/shared
```

This contains all configuration files and data.

### Accessibility

In bridge mode (default), some ports have to be published for the host to reach the services inside the container. By default, seahub runs on port `8000` and the file server on port `8082`.

```
-p 8000:8000 -p 8082:8082
```

### Parameters

All these parameters have to be passed as environment variables. Except for `PUID` and `GUID`, they're useful for initialization only (first run) and can be removed afterwards (even mandatory ones).

| Parameter | Description |
|:-|:-|
|`PUID`| *(Optional)* User id of the `seafile` user within the container. Use it to match uid on the host and avoid permission issues. *Default: 1000*|
|`PGID`| *(Optional)* Idem for group id. *Default: 1000* |
|`SERVER_IP`| *(Optional)* IP address **or** domain used to access the Seafile server from the outside. *Default: 127.0.0.1*|
|`PORT`|*(Optional)* Port used with the `SERVER_IP`. *Default: 80/443*|
|`SEAHUB_PORT`|*(Optional)* Port used by the Seahub service inside the container. *Default: 8000*|
|`FILESERVER_PORT`|*(Optional)* Port used by the file server service inside the container. *Default: 8082*|
|`CONTAINER_IP`|*(Optional)* IP address **or** hostname of the container. Since it's recommended to use a web server (for example Nginx) in front of the Seafile server, it will probably not communicate with the container using the `SERVER_IP`. Thus this option is needed for proper binding. *Default: 127.0.0.1*|
|`ENABLE_TLS`|*(Optional)* Set to non empty to enable https usage. *Default: empty string*|
|`SEAFILE_ADMIN_EMAIL`|**(Mandatory)** Email address of the admin account.|
|`SEAFILE_ADMIN_PASSWORD`|**(Mandatory)** Password of the admin account.|
|`MYSQL_HOST`|*(Optional)* Hostname of the MySQL server. It has to be reachable from within the container, using Docker networks or host mode is probably the key here. *Default: 127.0.0.1*|
|`MYSQL_PORT`|*(Optional)* Port of the MySQL server. *Default: 3306*|
|`USE_EXISTING_DB`|*(Optional)* (0: Create new databases\|1: Use existing ones) Use already created databases or create new ones. Using existing DBs is a **fully untested** option but this is provided by the Seafile installation script. So, well, it's documented here. *Default: 0*|
|`MYSQL_USER`|*(Optional)* Standard user name. Will be granted admin permissions on all databases below. *Default: seafile*|
|`MYSQL_USER_PASSWD`|**(Mandatory if `MYSQL_USER` isn't `root`)** Standard user password.|
|`MYSQL_USER_HOST`|*(Optional)* Authorized host for the standard user. *Default: %*|
|`MYSQL_ROOT_PASSWD`|**(Mandatory)** Password of the root user. |
|`CCNET_DB`|*(Optional)* Name of the ccnet db. *Default: ccnet_db*|
|`SEAFILE_DB`|*(Optional)* Name of the seafile db. *Default: seafile_db*|
|`SEAHUB_DB`|*(Optional)* Name of the seahub db. *Default: seahub_db*|

### Manual setup 

For manually setting up a server (for example if you refuse to expose some sensitive data in the environment), just run:

```Bash
$ docker run --rm -it -v /path/to/seafile/data/:/shared franchetti/seafile-arm
```

>Note: `PUID` and `PGID` parameters are harmless and still usable here if needed.

After submiting the admin credentials, configure the server by editing what you need in the `conf` directory. Then, run:

```Bash
$ docker run --rm -v /path/to/seafile/data/:/shared 
                  -p 8000:8000 -p 8082:8082
                  franchetti/seafile-arm
```

>Note: This is **not** the intended way to use this image and this exists for legacy reasons. Thus, support may drop.