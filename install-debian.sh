#!/bin/bash
set -ex
cd /root

export TERM=xterm-256color
export CODENAME=$(lsb_release -cs 2>/dev/null)
export CODEVER=$(lsb_release -rs 2>/dev/null)
export GPGDIR=/usr/share/keyrings
export DEBIAN_FRONTEND=noninteractive

# Repository
apt-get update
apt-get -y install ca-certificates curl libterm-readline-gnu-perl apt-transport-https apt-utils
curl -fsSL https://deb.nodesource.com/setup_24.x | bash - 
curl -fsSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor > $GPGDIR/yarn.gpg
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor > $GPGDIR/docker.gpg
curl -fsSL http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | gpg --dearmor > $GPGDIR/pgdg.gpg
curl -fsSL https://packages.sury.org/php/apt.gpg | tee /usr/share/keyrings/deb.sury.org-php.gpg

echo "deb [signed-by=$GPGDIR/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
echo "deb [signed-by=$GPGDIR/docker.gpg] https://download.docker.com/linux/debian $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list
echo "deb [signed-by=$GPGDIR/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt/ $CODENAME-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
echo "deb [signed-by=$GPGDIR/deb.sury.org-php.gpg] https://packages.sury.org/php/ $CODENAME main" | tee /etc/apt/sources.list.d/php.list
# virtualmin 8
curl -fsSL https://download.virtualmin.dev/virtualmin-install.sh | sh -s -- --setup --verbose
# Installations
apt-get update
apt-get -y install bzip2 bison btop chromium clang certbot cmake git ncdu htop iftop ipset jq lsof make nano ninja-build ncurses-bin nodejs patch ripgrep ruby rsync screen socat strace tar time tmux vim wget whois xz-utils zstd \
        libcurl4-openssl-dev libffi-dev libfuse3-dev libsqlite3-dev libtool libssl-dev libyaml-dev brotli libbz2-dev libgl1-mesa-dev libldap2-dev libpcre2-dev python3-dev libreadline-dev redis-server libxmlsec1-dev python3-pip ruby-json ruby-rack \
        language-pack-en libc-bin libdbd-pg-perl libdbd-mysql-perl liblwp-protocol-https-perl libdatetime-perl libcrypt-ssleay-perl libtext-asciitable-perl libio-tty-perl libxml-simple-perl libpq-dev webmin zsh
apt-get -y install webmin-{virtual-server,virtualmin-nginx,virtualmin-nginx-ssl,ruby-gems} virtualmin-config valkey-server fail2ban mariadb-server nftables bind9 sudo openssh-server systemd-container

# Postfix
echo "postfix postfix/mailname string debian.local" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
apt-get -y install postfix

# Docker
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin dbus-user-session uidmap slirp4netns docker-ce-rootless-extras passt uidmap

# Postgres
PG=17
apt-get -y install postgresql-$PG

if [[ -n "$OPTIONAL_INSTALL" ]]; then
  # Not everyone needs this. Also, postgresql-server-dev install would also install clang n gcc toolset
  apt -y install postgresql-$PG-{postgis,pgrouting,pgvector,timescaledb} postgresql-server-dev-$PG
  for ext in "postgis-3" "postgis_raster" "postgis_sfcgal" "postgis_tiger_geocoders" "postgis_topology" "earthdistance" "address_standardizer" "address_standardizer_data_us" "pgrouting" "vector"; do
    echo "trusted = true" >> "/usr/share/postgresql/$PG/extension/$ext.control"
  done
fi

# PHP
apt-get -y install php{7.4,8.2,8.3,8.4,8.5}-{bcmath,cli,common,curl,dev,fpm,gd,imap,igbinary,intl,mbstring,mysql,opcache,memcached,mongodb,pgsql,readline,redis,soap,xml,tidy,zip}
if [[ -n "$OPTIONAL_INSTALL" ]]; then
  apt-get -y install php{7.4,8.2,8.3,8.4,8.5}-{ldap,decimal,imagick,rdkafka,uuid,lz4,zstd}
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > $GPGDIR/microsoft.gpg
  echo "deb [signed-by=$GPGDIR/pgdg.gpg] https://packages.microsoft.com/debian/$CODEVER/prod $CODENAME main" | tee /etc/apt/sources.list.d/microsoft.list
  apt-get update && ACCEPT_EULA=Y apt-get -y install msodbcsql17
fi

# Misc
apt -y remove ufw redis-server
systemctl enable webmin mariadb postgresql nftables fail2ban named php{7.4,8.5}-fpm valkey-server || true
chmod +x /usr/local/bin/* && chown root:root /usr/local/bin/*

# Cleanup
apt -y upgrade
apt -y autoremove
