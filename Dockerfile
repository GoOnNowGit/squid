ARG SQUID_VERSION=5.5

FROM alpine as squid

ARG SQUID_VERSION

ENV SQUID_FINGERPRINT=CD6DBF8EF3B17D3E

RUN apk update && apk add --no-cache gnupg curl
RUN curl -OL http://www.squid-cache.org/Versions/v${SQUID_VERSION:0:1}/squid-${SQUID_VERSION}.tar.gz
RUN curl -OL http://www.squid-cache.org/Versions/v${SQUID_VERSION:0:1}/squid-${SQUID_VERSION}.tar.gz.asc
RUN gpg --no-tty --keyserver hkps://keyserver.ubuntu.com:443 --recv-keys ${SQUID_FINGERPRINT}
RUN gpg --verify squid-${SQUID_VERSION}.tar.gz.asc
RUN tar xf squid-${SQUID_VERSION}.tar.gz
###
###
###
FROM debian:buster-slim as ecap_libs

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  git \
  libecap3-dev \
  libexiv2-dev \
  libpodofo-dev \
  libtag1-dev \
  libtagc0-dev \
  libtool \
  libzip-dev \
  pkg-config

RUN git clone --depth 1 https://github.com/yvoinov/squid-ecap-gzip.git
RUN (cd squid-ecap-gzip; sh ./configure ; make -j $(getconf _NPROCESSORS_ONLN); make install-strip )

RUN git clone --branch 0.5.4 --depth 1 https://github.com/yvoinov/squid-ecap-exif.git
RUN (cd squid-ecap-exif; sh ./bootstrap.sh ; sh ./configure ; make -j $(getconf _NPROCESSORS_ONLN); make install-strip )
###
###
###
FROM debian:buster-slim as builder

ENV DEBIAN_FRONTEND=noninteractive

ARG SQUID_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV SQUID_CACHE_DIR=/var/spool/squid
ENV SQUID_LOG_DIR=/var/log/squid
ENV SQUID_USER=proxy
ENV SQUID_ERROR_LANG=English
ENV SQUID_PREFIX=/usr/local/squid

RUN echo "deb-src http://deb.debian.org/debian buster main" >> /etc/apt/sources.list
RUN apt update && apt-get build-dep -y squid
RUN apt install -y libssl-dev

COPY --from=squid squid-${SQUID_VERSION} squid-${SQUID_VERSION}

WORKDIR squid-${SQUID_VERSION}

RUN ./configure \
        'PKG_CONFIG_PATH=/usr/local/lib/pkgconfig' \
        --datadir=/usr/share/squid \
        --disable-arch-native \
        --disable-auth-basic \
        --disable-auth-digest \
        --disable-auth-negotiate \
        --disable-auth-ntlm \
        --disable-external-acl-helpers \
        --enable-async-io \
        --enable-cache-digests \
        --enable-delay-pools \
        --enable-dependency-tracking \
        --enable-ecap \
        --enable-err-language=${SQUID_ERROR_LANG} \
        --enable-esi \
        --enable-eui \
        --enable-follow-x-forwarded-for \
        --enable-forw-via-db \
        --enable-htpc \
        --enable-icap-client \
        --enable-icmp \
        --enable-inline \
        --enable-linux-netfilter \
        --enable-openssl \
        --enable-referer-log \
        --enable-removal-policies="lru,heap" \
        --enable-security-cert-validators="fake" \
        --enable-silent-rules \
        --enable-ssl-crtd \
        --enable-storeid-rewrite-helpers="file" \
        --enable-storeio="ufs,aufs,diskd,rock" \
        --enable-url-rewrite-helpers="fake" \
        --enable-useragent-log \
        --enable-zph-qos \
        --libexecdir=/usr/lib/squid \
        --prefix=${SQUID_PREFIX} \
        --sysconfdir=/etc/squid \
        --with-default-user=${SQUID_USER} \
        --with-large-files \
        --with-logdir=${SQUID_LOG_DIR} \
        --with-openssl \
        --with-pidfile=/var/run/squid.pid \
        --with-swapdir=${SQUID_CACHE_DIR} \
        --without-gnugss \
        --without-heimdal-krb5 \
        --without-mit-krb5 \
        --without-systemd

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN make install-strip
###
###
###
FROM debian:buster-slim as debian_main
LABEL org.opencontainers.image.source="https://github.com/goonnowgit/squid-container-fun"

ENV DEBIAN_FRONTEND=noninteractive
ENV SQUID_CACHE_DIR=/var/spool/squid
ENV SQUID_LOG_DIR=/var/log/squid
ENV SQUID_USER=proxy
ENV SQUID_ERROR_LANG=English
ENV SQUID_PREFIX=/usr/local/squid

COPY --from=builder /usr/lib/squid /usr/lib/squid
COPY --from=builder /usr/share/squid /usr/share/squid
COPY --from=builder /usr/local/squid /usr/local/squid
COPY --from=ecap_libs /usr/local/lib /usr/local/lib
COPY entrypoint.sh /sbin/entrypoint.sh

RUN apt update && apt install -y --no-install-recommends \
  ca-certificates \
  exiv2 \
  expat \
  libecap3 \
  libltdl7 \
  libnetfilter-conntrack3 \
  libnfnetlink0 \
  libpodofo0.9.6 \
  libstdc++6 \
  libtag1v5 \
  libtagc0 \
  libxml2 \
  libzip4 \
  libcap2 \
  && rm -rf /var/lib/apt/lists/* \
  && chown -R ${SQUID_USER}:${SQUID_USER} /usr/local/lib /usr/lib/squid /usr/share/squid /usr/local/squid \
  && chmod 0550 /sbin/entrypoint.sh \
  && chown ${SQUID_USER}:${SQUID_USER} /sbin/entrypoint.sh

EXPOSE 3128/tcp

ENTRYPOINT ["/sbin/entrypoint.sh"]
