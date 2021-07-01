# Seafile Docker image for ARM

A [Docker image](https://hub.docker.com/r/franchetti/seafile-arm) of the [Seafile](https://www.seafile.com/en/home/)  data synchronization system targeting ARMv7 and ARM64 platforms, like Raspberry Pi or Pine 64 boards. 

This repository is part of [a bigger project](https://github.com/ChatDeBlofeld/seafile-arm-docker) intended for bringing a full working Seafile environment (Seafile server, database server, web server with TLS support) in no time.

The build step uses the great [Seafile for Raspberry PI](https://github.com/haiwen/seafile-rpi) build script.

## Build

> Warning: you'll probably have to deal with the -h/-d options to get something working. [This repository](https://github.com/jobenvil/rpi-build-seafile) can help.

```
build_image.sh [OPTIONS]

Options:
    -t              Add a tag. Can be used several times.
    -l <platform>   Load to the local images. One <platform> at time only.
                    <platform> working choices can be: 
                        arm/v7 
                        arm64 
                        amd64
    -p              Push the image(s) to the remote registry. Incompatible with -l.
    -P              Override the default platform list. Incompatible with -l.
                    (default: linux/amd64,linux/arm/v7,linux/arm64)
    -v              Set seafile server version to build (default: 8.0.5)
    -h              Set python requirement file for seahub (default: official requirement file)
    -d              Set python requirement file for seafdav (default: official requirement file)
    -r              Registry to which upload the image (default: Docker Hub)
    -u              Repository to which upload the image (default: my Docker Hub username)
    -i              Image name (default: seafile-arm)
```

Example:

```Bash
$ ./build_image.sh -t 8 -t latest -l amd64
```

##  Run

Currently MySQL/MariaDB only.

>Note: SQLite support [planned](https://github.com/ChatDeBlofeld/seafile-arm-docker-base/issues/8), no expected date thought.

>Warning: connect to a MySQL 8 db could not work as expected, see [this issue](https://github.com/ChatDeBlofeld/seafile-arm-docker-base/issues/1) for more information.

Example of run, see below for a more detailed description of the arguments:

```Bash
$ docker run --rm -d --name seafile \
             -v /path/to/seafile/data/:/shared \
             -p 8000:8000 -p 8082:8082 \
             -e PUID=1001 -e PGID=1001 \
             -e TZ=Europe/Zurich
             -e SERVER_IP=cloud.my.domain \
             -e ENABLE_TLS=1 \
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

The installation is auto-configured and ready to be used behind Apache/Nginx, [as recommended in the manual](https://manual.seafile.com/deploy/using_mysql/#starting-seafile-server-and-seahub-website).

### Parameters

All these parameters have to be passed as environment variables. Except for `PUID`, `GUID` and `TZ`, they're useful for initialization only (first run) and can be removed afterwards (even mandatory ones).

| Parameter | Description |
|:-|:-|
|`PUID`| *(Optional)* User id of the `seafile` user within the container. Use it to match uid on the host and avoid permission issues. This is a [feature](https://docs.linuxserver.io/general/understanding-puid-and-pgid) taken from the *linuxserver* images. *Default: 1000*|
|`PGID`| *(Optional)* Idem for group id. *Default: 1000* |
|`TZ`| *(Optional)* Set the timezone of the container. *Default: UTC* |
|`SERVER_IP`| *(Optional)* IP address **or** domain used to access the Seafile server from the outside. *Default: 127.0.0.1*|
|`PORT`|*(Optional)* Port used with the `SERVER_IP`. *Default: 80/443*|
|`SEAHUB_PORT`|*(Optional)* Port used by the Seahub service inside the container. *Default: 8000*|
|`FILESERVER_PORT`|*(Optional)* Port used by the file server service inside the container. *Default: 8082*|
|`ENABLE_TLS`|*(Optional)* (0: Do not use TLS\|1: Use TLS) Enable https usage. *Default: 0*|
|`SEAFILE_ADMIN_EMAIL`|**(Mandatory)** Email address of the admin account.|
|`SEAFILE_ADMIN_PASSWORD`|**(Mandatory)** Password of the admin account.|
|`MYSQL_HOST`|*(Optional)* Hostname of the MySQL server. It has to be reachable from within the container, using Docker networks is probably the key here. *Default: 127.0.0.1*|
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

>Warning: This is **not** the intended way to use this image and this exists for legacy reasons. Thus, support may drop.

For manually setting up a server (for example if you refuse to expose some sensitive data in the environment), just run:

```Bash
$ docker run --rm -it -v /path/to/seafile/data/:/shared franchetti/seafile-arm
```

>Note: `PUID`, `PGID` and `TZ` parameters are harmless and still usefull here if needed.

After submiting the admin credentials, configure the server by editing what you need in the `conf` directory. Then, run something like this:

```Bash
$ docker run --rm -d --name seafile
             -v /path/to/seafile/data/:/shared \
             -p 8000:8000 -p 8082:8082 \
             -e TZ=Europe/Zurich \
             franchetti/seafile-arm
```

## Directory tree

After the first run, the volume will be filled with the following directories:

```
volume_root
├── conf
├── logs
├── media
├── seafile-data
└── seahub-data
```

## Customization

By editing files in the `conf` folder, you should be able to customize your installation as described in the [Seafile manual](https://manual.seafile.com/). All functionalities haven't been tested though and may or may not work, consult the open issues to know if there are known problems about what you want to use.

>Performance hint: for few users, decrease the number of workers in `gunicorn.conf.py` for lower RAM usage.
