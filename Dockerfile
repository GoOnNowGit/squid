ARG LATEST_RELEASE=5.4.1

FROM alpine as squid

ARG LATEST_RELEASE

ENV SQUID_FINGERPRINT=CD6DBF8EF3B17D3E

RUN apk update && apk add --no-cache gnupg curl
RUN curl -OL http://www.squid-cache.org/Versions/v${LATEST_RELEASE:0:1}/squid-${LATEST_RELEASE}.tar.gz
RUN curl -OL http://www.squid-cache.org/Versions/v${LATEST_RELEASE:0:1}/squid-${LATEST_RELEASE}.tar.gz.asc
RUN gpg --no-tty --keyserver hkps://keyserver.ubuntu.com:443 --recv-keys ${SQUID_FINGERPRINT}
RUN gpg --verify squid-${LATEST_RELEASE}.tar.gz.asc
RUN tar xf squid-${LATEST_RELEASE}.tar.gz
###
###
###
FROM debian:sid-slim as ecap_libs

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
RUN (cd squid-ecap-gzip; sh ./configure ; make -j $(getconf _NPROCESSORS_ONLN); make install )

RUN git clone --branch 0.5.4 --depth 1 https://github.com/yvoinov/squid-ecap-exif.git
RUN (cd squid-ecap-exif; sh ./bootstrap.sh ; sh ./configure ; make -j $(getconf _NPROCESSORS_ONLN); make install )
###
###
###
FROM debian:sid-slim as builder

ENV DEBIAN_FRONTEND=noninteractive

ARG LATEST_RELEASE

ENV DEBIAN_FRONTEND=noninteractive
ENV SQUID_CACHE_DIR=/var/spool/squid
ENV SQUID_LOG_DIR=/var/log/squid
ENV SQUID_USER=proxy
ENV SQUID_ERROR_LANG=English
ENV SQUID_PREFIX=/usr/local/squid

RUN echo "deb-src http://deb.debian.org/debian sid main" >> /etc/apt/sources.list
RUN apt update && apt-get build-dep -y squid

COPY --from=squid squid-${LATEST_RELEASE} squid-${LATEST_RELEASE}

WORKDIR squid-${LATEST_RELEASE}

RUN ./configure \
        'PKG_CONFIG_PATH=/usr/local/lib/pkgconfig' \
        --datadir=/usr/share/squid \
        --disable-arch-native \
        --enable-async-io \
        --enable-auth-basic="DB,fake,getpwnam,LDAP,NCSA,PAM,POP3,RADIUS,SASL" \
        --enable-auth-digest="file,LDAP" \
        --enable-auth-negotiate="kerberos,wrapper" \
        --enable-cache-digests \
        --enable-delay-pools \
        --enable-dependency-tracking \
        --enable-ecap \
        --enable-err-language=${SQUID_ERROR_LANG} \
        --enable-esi \
        --enable-eui \
        --enable-referer-log \
        --enable-openssl \
        --enable-external-acl-helpers="file_userip,kerberos_ldap_group,LDAP_group,session,SQL_session,time_quota,unix_group,wbinfo_group" \
        --enable-follow-x-forwarded-for \
        --enable-forw-via-db \
        --enable-htpc \
        --enable-icap-client \
        --enable-icmp \
        --enable-inline \
        --enable-linux-netfilter \
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
        --mandir=/usr/share/man \
        --prefix=${SQUID_PREFIX} \
        --sysconfdir=/etc/squid \
        --with-default-user=${SQUID_USER} \
        --with-large-files \
        --with-logdir=${SQUID_LOG_DIR} \
        --with-openssl \
        --with-pidfile=/var/run/squid.pid \
        --with-swapdir=${SQUID_CACHE_DIR} \
        --without-systemd

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN make install-strip
###
###
###
FROM debian:sid-slim as debian_main
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
  libldap-2.4-2 \
  libltdl7 \
  libnetfilter-conntrack3 \
  libnfnetlink0 \
  libpodofo-dev \
  libpodofo0.9.7 \
  libsasl2-2 \
  libsasl2-modules-db \
  libstdc++6 \
  libtag1v5 \
  libxml2 \
  libzip4 \
  && rm -rf /var/lib/apt/lists/* \
  && chown -R ${SQUID_USER}:${SQUID_USER} /usr/lib/squid /usr/share/squid /usr/local/squid \
  && chmod 0550 /sbin/entrypoint.sh \
  && chown ${SQUID_USER}:${SQUID_USER} /sbin/entrypoint.sh

EXPOSE 3128/tcp

ENTRYPOINT ["/sbin/entrypoint.sh"]
