#!/bin/bash
set -e
cd /root
export TERM=xterm-256color
export CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
export GPGDIR=/usr/share/keyrings
export DEBIAN_FRONTEND=noninteractive

# Repository
apt-get update
apt-get -y install ca-certificates curl libterm-readline-gnu-perl software-properties-common apt-transport-https apt-utils
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 
curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor > $GPGDIR/yarn.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > $GPGDIR/docker.gpg
curl -fsSL http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | gpg --dearmor > $GPGDIR/pgdg.gpg

echo "deb [signed-by=$GPGDIR/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
echo "deb [signed-by=$GPGDIR/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list
echo "deb [signed-by=$GPGDIR/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
curl -fsSL https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh | sh -s -- --setup --verbose
add-apt-repository ppa:ondrej/php

# Installations
apt-get update
apt-get -y install bzip2 bison btop clang certbot cmake git ncdu htop iftop ipset jq lsof make nano ninja-build ncurses-bin nodejs patch ripgrep ruby rsync screen socat strace tar time tmux vim wget whois xz-utils zstd \
        libcurl4-openssl-dev libffi-dev libsqlite3-dev libtool libssl-dev libyaml-dev brotli libbz2-dev libgl1-mesa-dev libldap2-dev libpcre2-dev python3-dev libreadline-dev redis-server libxmlsec1-dev python3-pip ruby-json ruby-rack \
        language-pack-en libc-bin libdbd-pg-perl libdbd-mysql-perl liblwp-protocol-https-perl libdatetime-perl libcrypt-ssleay-perl libtext-asciitable-perl libio-tty-perl libxml-simple-perl libpq-dev webmin
apt-get -y install webmin-{virtual-server,virtualmin-nginx,virtualmin-nginx-ssl,ruby-gems} virtualmin-config valkey-server earlyoom fail2ban mariadb-server nftables bind9 sudo openssh-server systemd-container

# Postfix
echo "postfix postfix/mailname string ubuntu.local" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
apt-get -y install postfix

# NGINX
BUILDER_DIR=/usr/local/lib/nginx-builder; [ ! -d "$BUILDER_DIR" ] && \
git clone https://github.com/domcloud/nginx-builder/ $BUILDER_DIR || git -C $BUILDER_DIR pull
cd $BUILDER_DIR/ && make install DOWNLOAD_V=1.1.1 && make clean && cd /root
ln -fs /usr/local/sbin/nginx /usr/sbin/nginx # nginx compatibility

# Docker
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Postgres
PG=17
apt-get -y install postgresql-$PG

# Not everyone needs this. Also, postgresql-server-dev install would also install clang n gcc toolset
# apt -y install postgresql-$PG-{postgis,pgrouting,pgvector,timescaledb} postgresql-server-dev-$PG
# for ext in "postgis-3" "postgis_raster" "postgis_sfcgal" "postgis_tiger_geocoders" "postgis_topology" "earthdistance" "address_standardizer" "address_standardizer_data_us" "pgrouting" "vector"; do
#   echo "trusted = true" >> "/usr/share/postgresql/$PG/extension/$ext.control"
# done

# PHP
apt-get -y install php{7.4,8.4}-{bcmath,cli,common,curl,dev,fpm,gd,imap,igbinary,intl,mbstring,mysql,opcache,mongodb,readline,redis,zip,pgsql,soap,xml}
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
find /etc/php/ -maxdepth 1 -mindepth 1 -exec sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 512M/g" {}/fpm/php.ini \; -exec sed -i "s/post_max_size = 8M/post_max_size = 512M/g" {}/fpm/php.ini \; 
find /etc/php/ -type f -name www.conf -print0 | xargs -0 sed -i 's/pm = dynamic/pm = ondemand/g'

# Proxyfix
PROXYFIX=proxy-fix-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" )
if ! command -v proxfix &> /dev/null; then
  wget https://github.com/domcloud/proxy-fix/releases/download/v0.2.5/$PROXYFIX.tar.gz
  tar -xf $PROXYFIX.tar.gz && mv $PROXYFIX /usr/local/bin/proxfix && rm -rf $PROXYFIX*
fi

# Pathman
PATHMAN=pathman-v0.6.0-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64_v1" )
if ! command -v pathman &> /dev/null; then
  wget -O pathman.tar.gz https://github.com/therootcompany/pathman/releases/download/v0.6.0/$PATHMAN.tar.gz
  tar -xf pathman.tar.gz && mv $PATHMAN /usr/local/bin/pathman && rm -f pathman.tar.gz
fi

# NVIM for NvChad
NVIM_V=0.10.4
if ! command -v neovim &> /dev/null; then
  NVIM_F=nvim-linux-$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
  curl -sSLO https://github.com/neovim/neovim/releases/download/v$NVIM_V/$NVIM_F.tar.gz
  tar -xf $NVIM_F.tar.gz && chown -R root:root $NVIM_F && rsync -a $NVIM_F/ /usr/local/ && rm -rf $NVIM_F*
fi

# Lazygit for NVIM
LAZYGIT=lazygit_0.46.0_Linux_$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64" )
if ! command -v lazygit &> /dev/null; then
  curl -sSLO https://github.com/jesseduffield/lazygit/releases/download/v0.46.0/$LAZYGIT.tar.gz
  tar -xf $LAZYGIT.tar.gz && mv lazygit /usr/local/bin/ && rm -f $LAZYGIT.tar.gz
fi

# Neofetch (Forked)
curl -sSLo /usr/local/bin/neofetch https://github.com/hykilpikonna/hyfetch/raw/1.4.11/neofetch

# Rdfind
RDFIND=rdfind-1.6.0
curl -sSL https://rdfind.pauldreik.se/$RDFIND.tar.gz | tar -xzf -
cd $RDFIND; ./configure --disable-debug ; make install; cd .. ; rm -rf $RDFIND*

# Misc
apt -y remove ufw redis-server
apt -y upgrade
apt -y autoremove
systemctl enable webmin mariadb postgresql nftables fail2ban named php{7.4,8.4}-fpm earlyoom valkey-server || true
chmod +x /usr/local/bin/* && chown root:root /usr/local/bin/*
