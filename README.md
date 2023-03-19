# Seafile Docker image for ARM

> **NOTE : Since Seafile 9, an [official Docker image](https://forum.seafile.com/t/seafile-community-edition-9-0-1-is-ready-arm64-is-supported-now/15480) for arm64 is available. Nevertheless, this repository will continue to be updated.**

A [Docker image](https://hub.docker.com/r/franchetti/seafile-arm) of the [Seafile](https://www.seafile.com/en/home/)  data synchronization system targeting ARMv7 and ARM64 platforms, like Raspberry Pi or Pine 64 boards. 

This repository is part of [a bigger project](https://github.com/ChatDeBlofeld/seafile-arm-docker) intended for bringing a full working Seafile environment (Seafile server, database server, web server with TLS support) in no time.

The build step uses the great [Seafile for Raspberry PI](https://github.com/haiwen/seafile-rpi) build script.

## Build

Copy the `.env.example` file to `.env`. Then you can either update the dotenv for your needs or use the command line arguments.

```
build_image.sh [OPTIONS]

Command line arguments take precedence over settings defined in the .env file

Options:
    -t              Add a tag. Can be used several times
    -l <platform>   Load to the local images. One <platform> at time only.
                    <platform> working choices can be: 
                        arm/v7 
                        arm64 
                        amd64
    -p              Push the image(s) to the remote registry. Incompatible with -l.
    -R              Image revision
    -f              Set a specific Dockerfile (default: Dockerfile)
    -D              Build directory (default: current directory)
    -P              Override the default platform list. Incompatible with -l.
    -v              Set seafile server version to build
    -B              Builder image used to build Seafile
    -r              Registry to which upload the image. Need to be set before -t.
    -u              Repository to which upload the image. Need to be set before -t.
    -i              Image name. Need to be set before -t.
    -q              Quiet mode.
```

Example:

```Bash
$ ./build_image.sh -t 8 -t latest -l amd64
```

### Builder

Image used to cache build dependencies in Dockerfile first stage can be built using the `Dockerfile.builder` file with the `-f` option.

## Run

Example of run, see below for a more detailed description of the arguments:

```Bash
$ docker run --rm -d --name seafile \
             -v /path/to/seafile/data/:/shared \
             -p 8000:8000 -p 8082:8082 \
             -e PUID=1001 -e PGID=1001 \
             -e TZ=Europe/Zurich
             -e SERVER_IP=cloud.my.domain \
             -e USE_HTTPS=1 \
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

In bridge mode (default), some ports have to be published for the host to reach the services inside the container. Seahub runs on port `8000` and the file server on port `8082`.

```
-p 8000:8000 -p 8082:8082
```

The installation is auto-configured and ready to be used behind Apache/Nginx, [as recommended in the manual](https://manual.seafile.com/deploy/using_mysql/#starting-seafile-server-and-seahub-website).

### Basic parameters

All these parameters have to be passed as environment variables. Except for `PUID`, `GUID` and `TZ`, they're useful for initialization only (first run) and can be removed afterwards (even mandatory ones).

| Parameter | Description |
|:-|:-|
|`PUID`| *(Optional)* User id of the `seafile` user within the container. Use it to match uid on the host and avoid permission issues. This is a [feature](https://docs.linuxserver.io/general/understanding-puid-and-pgid) taken from the *linuxserver* images. *Default: 1000*|
|`PGID`| *(Optional)* Idem for group id. *Default: 1000* |
|`TZ`| *(Optional)* Set the timezone of the container. *Default: UTC* |
|`SQLITE`| *(Optional)* (0: MySQL/MariaDB setup\|1: SQLite setup) Set the setup script to use. *Default: 0* |
|`SERVER_IP`| *(Optional)* IP address **or** domain used to access the Seafile server from the outside. *Default: 127.0.0.1*|
|`PORT`|*(Optional)* Port used with the `SERVER_IP`. *Default: 80/443*|
|`USE_HTTPS`|*(Optional)* (0: Unsecured access is used\|1: Secured access is used) Write configuration for https usage. **This has nothing to do with TLS certificates, it only writes some configuration files as you can see [here](https://manual.seafile.com/deploy/https_with_nginx/#modifying-ccnetconf)**. *Default: 0*|
|`SEAFILE_ADMIN_EMAIL`|**(Mandatory)** Email address of the admin account.|
|`SEAFILE_ADMIN_PASSWORD`|**(Mandatory)** Password of the admin account.|


#### MySQL/MariaDB specific parameters

I you want a MySQL/MariaDB deployment, you'll have to/can deal with some additional parameters.

| Parameter | Description |
|:-|:-|
|`MYSQL_HOST`|*(Optional)* Hostname of the MySQL server. It has to be reachable from within the container, using Docker networks is probably the key here. *Default: 127.0.0.1*|
|`MYSQL_PORT`|*(Optional)* Port of the MySQL server. *Default: 3306*|
|`USE_EXISTING_DB`|*(Optional)* (0: Create new databases\|1: Use existing ones) Use already created databases or create new ones. Using existing DBs is a **fully untested** option but this is provided by the Seafile installation script. So, well, it's documented here. *Default: 0*|
|`MYSQL_USER`|*(Optional)* Standard user name. Will be created and granted admin permissions on all databases below. *Default: seafile*|
|`MYSQL_USER_PASSWD`|**(Mandatory if `MYSQL_USER` isn't `root`)** Standard user password.|
|`MYSQL_USER_HOST`|*(Optional)* Authorized host for the standard user. *Default: %*|
|`MYSQL_ROOT_PASSWD`|**(Mandatory)** Password of the root user. |
|`CCNET_DB`|*(Optional)* Name of the ccnet db. *Default: ccnet_db*|
|`SEAFILE_DB`|*(Optional)* Name of the seafile db. *Default: seafile_db*|
|`SEAHUB_DB`|*(Optional)* Name of the seahub db. *Default: seahub_db*|

### Extensions and customization

In addition of the basic configuration described above, you can tune your configuration (as described in the [Seafile manual](https://manual.seafile.com/)) using the optional parameters below (at **initialization only**).

You can of course edit the various config files yourself but those configurations are not tested and may or may not work, consult the open issues to know if there are known problems about what you want to use.

| Parameter | Description |
|:-|:-|
|`MEMCACHED_HOST`|Host of the memcached server. More in [the manual](https://manual.seafile.com/deploy/add_memcached/).|

### Garbage collection

Garbage collection is not integrated (and won't be anytime soon) but can easily be triggered with a cron job on the host. See:

```bash
$ docker stop <seafile container>
$ docker run --rm -v /path/to/seafile/data/:/shared -e PUID=<PUID> -e PGID=<PGID> franchetti/seafile-arm gc
$ docker start <seafile container>
```

Obviously you probably want a compose topology wich makes things even easier:

```bash
$ docker compose stop <seafile service>
$ docker compose run --rm <seafile service> gc
$ docker compose start <seafile service>
```

### Manual setup 

>Warning: This is **not** the intended way to use this image and this exists for legacy reasons. Thus, support may drop.

For manually setting up a server (for example if you refuse to expose some sensitive data in the environment), just run:

```Bash
$ docker run --rm -it -e SQLITE=0 -v /path/to/seafile/data/:/shared franchetti/seafile-arm
```

>Note: `PUID`, `PGID` and `TZ` parameters are harmless and still useful here if needed.

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
├── seahub-data
└── sqlite (SQLite installation only)
```

## Miscellaneous

>Performance hint: for few users, decrease the number of workers in `gunicorn.conf.py` for lower RAM usage.
