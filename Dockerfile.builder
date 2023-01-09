FROM ubuntu:jammy

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
# FIXME: This is preferred to pip installation since cross-building wheels is probably
# a circle of hell by itself. A solution would be to have one Dockerfile per arch
# Point is that native packages are way bigger than pip wheels (no idea why) and thus 
# the least used archs are currently damaging the others. In addition, if distro version
# of a package breaks something, it must be installed from pip anyway (most packages can 
# still be built with pip though, let's say all but "cryptography").
# Note: native packages need (obviously) to be installed in runtime stage too.
COPY requirements .

RUN apt-get update -y \
    && grep -vE '^#' native.txt | xargs apt-get install -y

RUN mkdir -p /haiwen-build/seahub_thirdparty \
    && python3 -m pip install -r seafdav.txt --target /haiwen-build/seahub_thirdparty --no-deps \
    && python3 -m pip install -r seahub.txt --target /haiwen-build/seahub_thirdparty --no-deps