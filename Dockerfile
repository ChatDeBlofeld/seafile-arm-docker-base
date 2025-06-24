FROM ubuntu:noble

ARG TARGETPLATFORM

COPY requirements /requirements

RUN apt-get update && apt-get upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    sudo \
    tzdata \
    procps \
    sqlite3 \
    libmariadb3 \
    libmemcached11t64 \
    libldap2 \
    python3 \
    && /requirements/install.sh -nl $TARGETPLATFORM
    # FIXME: apt broken when removing this folder
    # && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/seafile

# Rights management
RUN groupadd -g 999 runtime \
    && useradd -ms /bin/bash -G sudo,runtime seafile \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && chown seafile:runtime . \
    && chmod g+w .
    
COPY --chown=seafile:runtime seafile/$TARGETPLATFORM /opt/seafile
COPY docker_entrypoint.sh /
COPY --chown=seafile:seafile scripts /home/seafile

ARG SEAFILE_SERVER_VERSION
ARG REVISION

# Add Seafile version in container context
ENV SEAFILE_SERVER_VERSION=$SEAFILE_SERVER_VERSION

# Add image revision in container context
ENV REVISION=$REVISION

EXPOSE 8000 8080 8082 8083

ENTRYPOINT ["/docker_entrypoint.sh"]
CMD ["launch"]
