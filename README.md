# Seafile Docker image for ARM

> **NOTE : Since Seafile 9, an [official Docker image](https://forum.seafile.com/t/seafile-community-edition-9-0-1-is-ready-arm64-is-supported-now/15480) for arm64 is available. Nevertheless, this repository will continue to be updated.**

A [Docker image](https://hub.docker.com/r/franchetti/seafile-arm) of the [Seafile](https://www.seafile.com/en/home/)  data synchronization system targeting ARMv7 and ARM64 platforms, like Raspberry Pi or Pine 64 boards. 

This repository is part of [a bigger project](https://github.com/ChatDeBlofeld/seafile-arm-docker) intended for bringing a full working Seafile environment (Seafile server, database server, web server with TLS support) in no time.

The build step uses the great [Seafile for Raspberry PI](https://github.com/haiwen/seafile-rpi) build script.


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

### Reachability

In bridge mode (default), some ports have to be published for the host to reach the services inside the container. Seahub runs on port `8000` and the file server on port `8082`.

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
|`USE_HTTPS`|*(Optional)* (0: Unsecured access is used\|1: Secured access is used) Write configuration for https usage. **This has nothing to do with TLS certificates, it only writes some configuration files as you can see [here](https://manual.seafile.com/deploy/https_with_nginx/#modifying-ccnetconf)**. *Default: 0*|
|`SEAFILE_ADMIN_EMAIL`|**(Mandatory)** Email address of the admin account.|
|`SEAFILE_ADMIN_PASSWORD`|**(Mandatory)** Password of the admin account.|
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

You can of course edit the various config files yourself but all configurations are not tested and may or may not work, consult the open issues to know if there are known problems about what you want to use.

| Parameter | Description |
|:-|:-|
|`MEMCACHED_HOST`|Host of the memcached server. More in [the manual](https://manual.seafile.com/deploy/add_memcached/).|
|`WEBDAV`| Set to `1` to enable [webdav](https://manual.seafile.com/extension/webdav/) on port `8080` for location `/seafdav`.|
|`NOTIFICATION_SERVER`| Set to `1` to enable [notification server](https://manual.seafile.com/config/seafile-conf/#notification-server-configuration) on port `8083`.|

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

>Debug hint: when Seahub fails to start, set `daemon = False` in `gunicorn.conf.py` to run the server in the foreground, error messages will then be printed in the container logs instead of being dropped in the void of asynchronous workers.

## Build

### Pre-requisites

Copy the `.env.example` file to `.env`. Then you can either update the dotenv for your needs or use the command line arguments.

To build the python dependencies, you'll need a builder image. Such an image can be build with my fork of the [Seafile for Raspberry PI](https://github.com/ChatDeBlofeld/seafile-rpi) build script.

Pre-compiled Seafile packages (that can be built with the script above) are also needed. 

### Prepare build

Every platform needs more or less python dependencies, that have to be built from source if no wheel is available. Dependencies are managed in the `requirements` folder. Rule of thumb is that, if a wheel is available for the platform, use a python package, else a distribution package. Some other actions include uncompressing the Seafile packages and copying them to the right place.

the `prepare_build.sh` script handles that:

```
Usage: prepare_build.sh [options]

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
```

### Build the image

```
Usage: build_image.sh [options]

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
```
