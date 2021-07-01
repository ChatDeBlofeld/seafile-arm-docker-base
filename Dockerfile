ARG VERSION

FROM debian:buster AS builder

ARG VERSION
ARG PYTHON_REQUIREMENTS_URL_SEAHUB
ARG PYTHON_REQUIREMENTS_URL_SEAFDAV

RUN apt-get update -y && apt-get install -y \
    wget \
    sudo \
    libmemcached-dev

# Retrieve seafile build script
RUN wget https://raw.githubusercontent.com/haiwen/seafile-rpi/master/build3.sh
RUN chmod u+x build3.sh

# Build each component separately for better cache and easy debug in case of failure

# Install dependencies and thirdparty requirements
RUN ./build3.sh -D -v $VERSION \
    -h $PYTHON_REQUIREMENTS_URL_SEAHUB \
    -d $PYTHON_REQUIREMENTS_URL_SEAFDAV
# Build libevhtp
RUN ./build3.sh -1 -v $VERSION
# Build libsearpc
RUN ./build3.sh -2 -v $VERSION
# Build seafile
RUN ./build3.sh -3 -v $VERSION
# Build seahub
RUN ./build3.sh -4 -v $VERSION
# Build seafobj
RUN ./build3.sh -5 -v $VERSION
# Build seafdav
RUN ./build3.sh -6 -v $VERSION
# Build Seafile server
RUN ./build3.sh -7 -v $VERSION

# Extract package
RUN tar -xzf built-seafile-server-pkgs/*.tar.gz
RUN mkdir seafile && mv seafile-server-$VERSION seafile

WORKDIR /seafile

# Additional dependencies
RUN python3 -m pip install --target seafile-server-$VERSION/seahub/thirdpart --upgrade \
    # Memcached
    pylibmc \
    django-pylibmc

# Fix import not found when running seafile
RUN ln -s python3.7 seafile-server-$VERSION/seafile/lib/python3.6

# Prepare media folder to be exposed
RUN mv seafile-server-$VERSION/seahub/media . && echo $VERSION > ./media/version

COPY custom/setup-seafile-mysql.py seafile-server-$VERSION/

FROM debian:buster-slim

ARG VERSION

RUN apt-get update && apt-get install --no-install-recommends -y \
    sudo \
    procps \
    libmariadb3 \
    libmemcached11 \
    python3 \
    python3-setuptools \
    python3-ldap \
    python3-sqlalchemy \
    # Improve Mysql 8 suppport
    python3-cryptography \
    # Folowing libs are useful for the armv7 arch only
    # Since they're not heavy, no need to create separate pipelines atm
    libjpeg62-turbo \
    libopenjp2-7 \
    libtiff5 \
    libxcb1 \
    libfreetype6 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/seafile

RUN useradd -ms /bin/bash -G sudo seafile \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && chown -R seafile:seafile /opt/seafile

COPY --from=builder --chown=seafile:seafile /seafile /opt/seafile

COPY docker_entrypoint.sh /
COPY --chown=seafile:seafile scripts /home/seafile

# Add version in container context
ENV SEAFILE_SERVER_VERSION $VERSION

CMD ["/docker_entrypoint.sh"]
