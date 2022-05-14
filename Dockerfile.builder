FROM ubuntu:jammy

ARG SEAFILE_SERVER_VERSION
ARG PYTHON_REQUIREMENTS_URL_SEAHUB
ARG PYTHON_REQUIREMENTS_URL_SEAFDAV

RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
    tzdata \
    wget \
    sudo \
    libmemcached-dev \
    # needed for pillow to properly display captcha (and something else?)
    libfreetype-dev

# FIXME: TLS broken on arm/v7 on focal
# RUN update-ca-certificates -f

# Retrieve seafile build script
RUN wget https://raw.githubusercontent.com/haiwen/seafile-rpi/master/build.sh
RUN chmod u+x build.sh

# Build each component separately for better cache and easy debug in case of failure

# Install build dependencies
RUN ./build.sh -D