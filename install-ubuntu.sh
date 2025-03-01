#!/bin/bash
set -e
cd /root
export TERM=xterm-256color
export CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
export GPGDIR=/usr/share/keyrings

# Repository
apt-get update
apt-get -y install ca-certificates curl libterm-readline-gnu-perl software-properties-common
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 
curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o $GPGDIR/yarn.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o $GPGDIR/docker.gpg
curl -fsSL http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | gpg --dearmor -o $GPGDIR/pgdg.gpg

echo "deb [signed-by=$GPGDIR/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
echo "deb [signed-by=$GPGDIR/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list
echo "deb [signed-by=$GPGDIR/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup --verbose
add-apt-repository ppa:ondrej/php

# Installations
apt-get update
apt-get -y install bzip2 bison btop clang certbot cmake git ncdu htop iftop ipset jq lsof make nano ninja-build ncurses-bin nodejs patch ripgrep ruby rsync screen socat strace tar time tmux vim wget whois xz-utils zstd \
        libcurl4-openssl-dev libffi-dev libsqlite3-dev libtool libssl-dev libyaml-dev brotli libbz2-dev libgl1-mesa-dev libldap2-dev libpcre2-dev python3-dev libreadline-dev redis-server libxmlsec1-dev python3-pip ruby-json ruby-rack \
        language-pack-en libc-bin libdbd-pg-perl libdbd-mysql-perl liblwp-protocol-https-perl libdatetime-perl libcrypt-ssleay-perl libtext-asciitable-perl libio-tty-perl libxml-simple-perl libpq-dev pgdg-keyring
apt-get -y install webmin valkey-server earlyoom fail2ban nftables postfix bind9 sudo openssh-server systemd-container

# Docker
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
