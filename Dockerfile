FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential clang flex bison gawk gettext git rsync unzip \
    libncurses-dev libssl-dev libelf-dev zlib1g-dev \
    python3 python3-setuptools python3-dev swig wget curl file \
    zstd ccache shellcheck ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ARG BUILD_UID=1000
ARG BUILD_GID=1000
# Ubuntu's base image already has uid/gid 1000. Reuse its account.
RUN usermod -l builder ubuntu && groupmod -n builder ubuntu \
    && groupmod -g ${BUILD_GID} builder && usermod -u ${BUILD_UID} builder
USER builder
WORKDIR /work
ENV FLAVOR=all
ENTRYPOINT ["bash", "build.sh"]
