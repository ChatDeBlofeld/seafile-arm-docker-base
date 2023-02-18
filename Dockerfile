ARG BUILDER_IMAGE

FROM --platform=$TARGETPLATFORM $BUILDER_IMAGE AS builder

ARG SEAFILE_SERVER_VERSION

# Build libevhtp
RUN ./build.sh -1 -v $SEAFILE_SERVER_VERSION
# Build libsearpc
RUN ./build.sh -2 -v $SEAFILE_SERVER_VERSION
# Build seafile (c_fileserver)
RUN ./build.sh -3 -v $SEAFILE_SERVER_VERSION
# Build seafile (go_fileserver)
RUN ./build.sh -4 -v $SEAFILE_SERVER_VERSION
# Build seahub
RUN ./build.sh -5 -v $SEAFILE_SERVER_VERSION
# Build seafobj
RUN ./build.sh -6 -v $SEAFILE_SERVER_VERSION
# Build seafdav
RUN ./build.sh -7 -v $SEAFILE_SERVER_VERSION
# Build Seafile server
RUN ./build.sh -8 -v $SEAFILE_SERVER_VERSION

# Extract package
RUN tar -xzf built-seafile-server-pkgs/*.tar.gz
RUN mkdir seafile \
    && mv seafile-server-$SEAFILE_SERVER_VERSION seafile \
    && mv /haiwen-build/seafile-server/fileserver/fileserver seafile/seafile-server-$SEAFILE_SERVER_VERSION/seafile/bin/ 

WORKDIR /seafile

# Prepare media folder to be exposed
RUN mv seafile-server-$SEAFILE_SERVER_VERSION/seahub/media . \
    && echo $SEAFILE_SERVER_VERSION > ./media/version

COPY custom/setup-seafile-mysql.py seafile-server-$SEAFILE_SERVER_VERSION/setup-seafile-mysql.py
COPY custom/db_update_helper.py seafile-server-$SEAFILE_SERVER_VERSION/upgrade/db_update_helper.py

RUN chmod -R g+w .

FROM ubuntu:jammy

COPY requirements/native.txt /

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo \
    tzdata \
    procps \
    sqlite3 \
    libmariadb3 \
    libmemcached11 \
    python3 \
    # Folowing libs are useful for the armv7 arch only
    # Since they're not heavy, no need to create separate pipelines atm
    libopenjp2-7 \
    libtiff5 \
    libxcb1 \
    libfreetype6 \
    && grep -vE '^#' /native.txt | xargs apt-get install --no-install-recommends -y \
    && rm -rf /var/lib/apt/lists/*

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

ARG SEAFILE_SERVER_VERSION
ARG REVISION

# Add Seafile version in container context
ENV SEAFILE_SERVER_VERSION $SEAFILE_SERVER_VERSION

# Add image revision in container context
ENV REVISION $REVISION

EXPOSE 8000 8080 8082

CMD ["/docker_entrypoint.sh"]
