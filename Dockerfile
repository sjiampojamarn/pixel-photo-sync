ARG BUILD_FROM
FROM ${BUILD_FROM} as BUILD_IMAGE

ENV DEBCONF_NONINTERACTIVE_SEEN=true \
    DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=en_US.utf8 \
    TZ=America/Los_Angeles

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* 

COPY ./*.sh ./ 

RUN apt-get update \
    && apt-get install -y locales \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && apt-get install -y inotify-tools rsync ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x *.sh

USER 33:33
CMD ["/bin/sh" "-c" "./pixel-photo-sync.sh"]
