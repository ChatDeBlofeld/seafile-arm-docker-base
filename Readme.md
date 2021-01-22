# Seafile Docker image for ARM

## About

Currently MySQL only.

## Build

Update the `USER` variable in the `build-image.sh` script, then run it.

Script usage:

```
./build-image.sh
    -t              Add a tag. Could be used several times.
    -l <platform>   Load to the local images. One <platform> at time only.
    -p              Push the image(s) to the remote registry. Incompatible with -p
```

Example:

```
./build-image.sh -t 7.1.9 -t latest -l amd64
```

##  Run

Installation:

```
docker run -it --rm -v /path/to/seafile/data/:/shared franchetti/seafile-arm /docker_entrypoint.sh init
```

Run:

```
docker run -v /path/to/seafile/data/:/shared franchetti/seafile-arm
```

>Note: You may have to expose some ports with `-p` depending on what you're trying to achieve.