FROM --platform=$TARGETPLATFORM ubuntu:jammy-20221130

ARG TARGETPLATFORM

RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
    tzdata \
    wget \
    sudo \
    libmemcached-dev \
    # needed for pillow to properly display captcha (and something else?)
    # TODO: not sure if still needed since Pillow isn't compiled anymore
    # (either fetched as wheel or binary with apt)
    libfreetype-dev

# Install build dependencies
COPY ./build.sh ./build.sh
RUN ./build.sh -D

# Installing python dependencies, mixing native and pip packages
COPY requirements /requirements
RUN /requirements/install.sh -nl $TARGETPLATFORM