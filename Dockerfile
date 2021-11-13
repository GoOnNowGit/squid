ARG LATEST_RELEASE=5.1

FROM alpine as squid

ARG LATEST_RELEASE

ENV SQUID_FINGERPRINT=CD6DBF8EF3B17D3E

RUN apk update && apk add --no-cache gnupg curl
RUN curl -OL http://www.squid-cache.org/Versions/v${LATEST_RELEASE:0:1}/squid-${LATEST_RELEASE}.tar.gz
RUN curl -OL http://www.squid-cache.org/Versions/v${LATEST_RELEASE:0:1}/squid-${LATEST_RELEASE}.tar.gz.asc
RUN gpg --no-tty --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ${SQUID_FINGERPRINT} 
RUN gpg --verify squid-${LATEST_RELEASE}.tar.gz.asc
RUN tar xf squid-${LATEST_RELEASE}.tar.gz
###
###
###
FROM debian:sid-slim as builder

ARG LATEST_RELEASE

ENV SQUID_CACHE_DIR=/var/spool/squid
ENV SQUID_LOG_DIR=/var/log/squid
ENV SQUID_USER=proxy
ENV SQUID_ERROR_LANG=English
ENV SQUID_PREFIX=/usr/local/squid

RUN echo "deb-src http://deb.debian.org/debian sid main" >> /etc/apt/sources.list
RUN apt update && apt-get build-dep -y squid
RUN apt install -y libecap3-dev --no-install-recommends 

COPY --from=squid squid-${LATEST_RELEASE} squid-${LATEST_RELEASE}

WORKDIR squid-${LATEST_RELEASE}

RUN ./configure \
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

ENV SQUID_CACHE_DIR=/var/spool/squid
ENV SQUID_LOG_DIR=/var/log/squid
ENV SQUID_USER=proxy
ENV SQUID_ERROR_LANG=English
ENV SQUID_PREFIX=/usr/local/squid

COPY --from=builder /usr/lib/squid /usr/lib/squid
COPY --from=builder /usr/share/squid /usr/share/squid
COPY --from=builder /usr/local/squid /usr/local/squid
COPY entrypoint.sh /sbin/entrypoint.sh

RUN apt update && apt install -y --no-install-recommends \
  ca-certificates \
  libxml2 \
  libltdl7 \
  libecap3 \
  expat \
  libldap-2.4-2 \
  libnfnetlink0 \
  libsasl2-2 \
  libsasl2-modules-db \
  libnetfilter-conntrack3 \
  && rm -rf /var/lib/apt/lists/* \
  && chown -R ${SQUID_USER}:${SQUID_USER} /usr/lib/squid /usr/share/squid /usr/local/squid \
  && chmod 0550 /sbin/entrypoint.sh \
  && chown ${SQUID_USER}:${SQUID_USER} /sbin/entrypoint.sh

EXPOSE 3128/tcp

ENTRYPOINT ["/sbin/entrypoint.sh"]

