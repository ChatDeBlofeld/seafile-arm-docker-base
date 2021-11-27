ARG SEAFILE_SERVER_VERSION

FROM debian:bullseye AS builder

ARG SEAFILE_SERVER_VERSION
ARG PYTHON_REQUIREMENTS_URL_SEAHUB
ARG PYTHON_REQUIREMENTS_URL_SEAFDAV

RUN apt-get update -y && apt-get install -y \
    wget \
    sudo \
    libmemcached-dev

# Retrieve seafile build script
# RUN wget https://raw.githubusercontent.com/haiwen/seafile-rpi/master/build3.sh
RUN wget https://raw.githubusercontent.com/ChatDeBlofeld/seafile-rpi/dev/build3.sh
RUN chmod u+x build3.sh

# Build each component separately for better cache and easy debug in case of failure

# Install dependencies and thirdparty requirements
RUN ./build3.sh -D -v $SEAFILE_SERVER_VERSION \
    -h $PYTHON_REQUIREMENTS_URL_SEAHUB \
    -d $PYTHON_REQUIREMENTS_URL_SEAFDAV
# Build libevhtp
RUN ./build3.sh -1 -v $SEAFILE_SERVER_VERSION
# Build libsearpc
RUN ./build3.sh -2 -v $SEAFILE_SERVER_VERSION
# Build seafile
RUN ./build3.sh -3 -v $SEAFILE_SERVER_VERSION
# Build seahub
RUN ./build3.sh -4 -v $SEAFILE_SERVER_VERSION
# Build seafobj
RUN ./build3.sh -5 -v $SEAFILE_SERVER_VERSION
# Build seafdav
RUN ./build3.sh -6 -v $SEAFILE_SERVER_VERSION
# Build Seafile server
RUN ./build3.sh -7 -v $SEAFILE_SERVER_VERSION

# Extract package
RUN tar -xzf built-seafile-server-pkgs/*.tar.gz
RUN mkdir seafile && mv seafile-server-$SEAFILE_SERVER_VERSION seafile

WORKDIR /seafile

# Additional dependencies
RUN python3 -m pip install --target seafile-server-$SEAFILE_SERVER_VERSION/seahub/thirdpart --upgrade \
    # Memcached
    pylibmc \
    django-pylibmc

# Prepare media folder to be exposed
RUN mv seafile-server-$SEAFILE_SERVER_VERSION/seahub/media . && echo $SEAFILE_SERVER_VERSION ./media/version

COPY custom/setup-seafile-mysql.py seafile-server-$SEAFILE_SERVER_VERSION/setup-seafile-mysql.py
COPY custom/db_update_helper.py seafile-server-$SEAFILE_SERVER_VERSION/upgrade/db_update_helper.py

RUN chmod -R g+w .

FROM debian:bullseye-slim

ARG SEAFILE_SERVER_VERSION
ARG REVISION

RUN apt-get update && apt-get install --no-install-recommends -y \
    sudo \
    procps \
    sqlite3 \
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

# Rights management
RUN groupadd -g 999 runtime \
    && useradd -ms /bin/bash -G sudo,runtime seafile \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && chown seafile:runtime . \
    && chmod g+w .

COPY --from=builder --chown=seafile:runtime /seafile /opt/seafile
COPY docker_entrypoint.sh /
COPY --chown=seafile:seafile scripts /home/seafile

# Add Seafile version in container context
ENV SEAFILE_SERVER_VERSION $SEAFILE_SERVER_VERSION

# Add image revision in container context
ENV REVISION $REVISION

CMD ["/docker_entrypoint.sh"]
