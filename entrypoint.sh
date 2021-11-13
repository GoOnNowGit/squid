#!/bin/bash
# base file from, https://github.com/sameersbn/docker-squid.git

set -e

export PATH=$SQUID_PREFIX/sbin:$PATH

create_log_dir() {
  mkdir -p ${SQUID_LOG_DIR}
  chmod -R 755 ${SQUID_LOG_DIR}
  chown -R ${SQUID_USER}:${SQUID_USER} ${SQUID_LOG_DIR}
}

create_cache_dir() {
  mkdir -p ${SQUID_CACHE_DIR}
  chown -R ${SQUID_USER}:${SQUID_USER} ${SQUID_CACHE_DIR}
}

create_ssl_db_dir() {
  if [ ! -e /var/lib/ssl_db/index.txt ]; then 
    /usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB
    chown -R ${SQUID_USER}:${SQUID_USER} /var/lib/ssl_db
  fi
}

create_log_dir
create_cache_dir
create_ssl_db_dir

# allow arguments to be passed to squid
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == squid || ${1} == $(which squid) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi

# default behaviour is to launch squid
if [[ -z ${1} ]]; then
  if [[ ! -d ${SQUID_CACHE_DIR}/00 ]]; then
    echo "Initializing cache..."
    $(which squid) -N -f /etc/squid/squid.conf -z
  fi
  echo "Starting squid..."
  exec $(which squid) -f /etc/squid/squid.conf -NYCd 1 ${EXTRA_ARGS}
else
  exec "$@"
fi
