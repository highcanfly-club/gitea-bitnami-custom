#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /opt/bitnami/scripts/libbitnami.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libos.sh

# Load Gitea environment variables
. /opt/bitnami/scripts/gitea-env.sh

print_welcome_page

# Simpler version of abs() function
function abs() {
    [ $1 -lt 0 ] && echo $((-$1)) || echo $1
}

# Generate pseudo random number based on the hash of the hostname
# This is to avoid multiple containers to do the same thing at the same time
# The random number is used to wait a random amount of time before starting the setup
# Basing the pseudo random number on the hostname hash allows to have a different number for each container
# Because the hostname as a different hash in each container
function get_pseudorandom_based_on_hash() {
    MIN=${1:-43}
    MAX=${2:-127}
    HOSTNAME=${3:-$(hostname)}
    HASH=$(echo -n "$HOSTNAME" | shasum | cut -f1 -d' ')
    HASH_FIRST_16="${HASH:0:16}"
    ABSHASH=$(abs $((0x$HASH_FIRST_16))) # convert hex to positive decimal
    RANDOM_NUMBER=$((($ABSHASH % ($MAX - $MIN)) + $MIN + 1))
    echo $RANDOM_NUMBER
}

function sleep_ms() {
    MS=$(printf "%04d" ${1:-1000} | sed 's/\(.*\)\([0-9]\{3\}\)$/\1.\2/')
    sleep $MS
}

_RANDOM=$(get_pseudorandom_based_on_hash 1000 10000)
info "Waiting for $_RANDOM milliseconds before starting the setup..."
sleep_ms $_RANDOM

# Configure libnss_wrapper based on the UID/GID used to run the container
# This container supports arbitrary UIDs, therefore we have do it dynamically
if ! am_i_root; then
    export LNAME="gitea"
    export LD_PRELOAD="/opt/bitnami/common/lib/libnss_wrapper.so"
    if [[ -f "$LD_PRELOAD" ]]; then
        info "Configuring libnss_wrapper"
        NSS_WRAPPER_PASSWD="$(mktemp)"
        export NSS_WRAPPER_PASSWD
        NSS_WRAPPER_GROUP="$(mktemp)"
        export NSS_WRAPPER_GROUP
        if [[ "$HOME" == "/" ]]; then
            export HOME=/opt/bitnami/gitea
        fi
        echo "gitea:x:$(id -u):$(id -g):gitea:${HOME}:/bin/false" >"$NSS_WRAPPER_PASSWD"
        echo "gitea:x:$(id -g):" >"$NSS_WRAPPER_GROUP"
        chmod 400 "$NSS_WRAPPER_PASSWD" "$NSS_WRAPPER_GROUP"
    fi
fi

if [[ "$1" = "/opt/bitnami/scripts/gitea/run.sh" ]]; then
    FILE="/bitnami/gitea/custom/conf/app.ini"
    LOCKFILE="/bitnami/gitea/.app.ini.lock"
    _RANDOM=$(get_pseudorandom_based_on_hash 60 120)
    DIRNAME=$(dirname "$LOCKFILE")
    mkdir -p "$DIRNAME"

    info "** Starting Gitea setup on $(hostname) **"
    # this loop is to wait for the bitnami/gitea/.app.ini.lock to be unlocked
    # the bitnami/gitea/.app.ini.lock is locked when the bitnami application is being setup
    while true; do
        exec 200>"$LOCKFILE"
        if flock -n 200; then
            info "$(hostname): The file $FILE is not write-locked."
            info "$(hostname): Locking the file for writing..."
            /opt/bitnami/scripts/gitea/setup.sh
            info "$(hostname): Unlocking the file..."
            flock -u 200
            info "$(hostname): The file $FILE is now unlocked."
            break
        else
            warn "$(hostname): The file $FILE is write-locked. Waiting for $_RANDOM seconds before retrying..."
            sleep $_RANDOM
        fi
    done
    info "** Gitea setup finished on $(hostname) ! **"
fi

echo ""
exec "$@"
