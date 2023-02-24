FROM --platform=$TARGETPLATFORM ubuntu:jammy

ARG TARGETPLATFORM

RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
    tzdata \
    wget \
    sudo \
    libmemcached-dev \
    # needed for pillow to properly display captcha (and something else?)
    libfreetype-dev

# Retrieve seafile build script
RUN wget https://raw.githubusercontent.com/haiwen/seafile-rpi/master/build.sh
RUN chmod u+x build.sh

# Install build dependencies
RUN ./build.sh -D

# Installing python dependencies, mixing native and pip packages
COPY requirements /requirements

RUN /requirements/install.sh -pnl $TARGETPLATFORM